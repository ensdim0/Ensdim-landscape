-- Fix visit-completed notifications: ensure body is always a full Arabic sentence.
-- Replaces the trigger function with a null-safe body, and back-fills existing
-- notifications that were stored with just 'إنهاء زيارة' as the body.

CREATE OR REPLACE FUNCTION public.notify_visit_completed_to_admins()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contract_code  text;
  v_supervisor_name text;
  v_completed_at   timestamptz;
  v_summary        text;
  v_body           text;
BEGIN
  IF tg_op <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF NEW.status <> 'completed' OR OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;

  BEGIN
    SELECT c.code
    INTO v_contract_code
    FROM public.contracts c
    WHERE c.id = NEW.contract_id;
  EXCEPTION WHEN OTHERS THEN
    v_contract_code := NULL;
  END;

  BEGIN
    SELECT coalesce(u.full_name, u.email, 'المشرف')
    INTO v_supervisor_name
    FROM public.task_executions te
    LEFT JOIN public.users u ON u.id = te.supervisor_id
    WHERE te.visit_id = NEW.id
    ORDER BY te.created_at DESC
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v_supervisor_name := NULL;
  END;

  v_completed_at := coalesce(NEW.completed_at, now());
  v_summary := nullif(trim(coalesce(NEW.summary, '')), '');

  -- Build body – null-safe so no part can collapse the whole string to NULL
  v_body :=
    coalesce(v_supervisor_name, 'المشرف') ||
    ' أنهى زيارة العقد ' ||
    coalesce(v_contract_code, 'غير معروف') ||
    coalesce(' بتاريخ ' || to_char(NEW.visit_date, 'YYYY-MM-DD'), '') ||
    CASE WHEN v_summary IS NOT NULL THEN ' - ملخص: ' || left(v_summary, 140) ELSE '' END;

  BEGIN
    INSERT INTO public.notifications (user_id, title, body, meta)
    SELECT
      ur.user_id,
      'تم إنهاء زيارة',
      v_body,
      jsonb_build_object(
        'type',            'visit_completed',
        'contract_id',     NEW.contract_id,
        'visit_id',        NEW.id,
        'visit_date',      NEW.visit_date,
        'completed_at',    v_completed_at,
        'summary',         coalesce(NEW.summary, ''),
        'supervisor_name', coalesce(v_supervisor_name, 'المشرف'),
        'contract_code',   coalesce(v_contract_code, '')
      )
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE r.name = 'admin';
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_visit_completed_to_admins ON public.visits;
CREATE TRIGGER trg_notify_visit_completed_to_admins
  AFTER UPDATE ON public.visits
  FOR EACH ROW EXECUTE FUNCTION public.notify_visit_completed_to_admins();

-- Back-fill existing notifications that were stored with the bare 'إنهاء زيارة' body.
-- Replace with a more informative label derived from the stored meta.
UPDATE public.notifications
SET body =
  coalesce(
    (meta->>'supervisor_name') || ' أنهى زيارة العقد ' ||
      coalesce(meta->>'contract_code', 'غير معروف') ||
      coalesce(' بتاريخ ' || (meta->>'visit_date'), ''),
    'تم إنهاء الزيارة'
  )
WHERE
  (meta->>'type') = 'visit_completed'
  AND (body IS NULL OR body = 'إنهاء زيارة' OR body = '');
