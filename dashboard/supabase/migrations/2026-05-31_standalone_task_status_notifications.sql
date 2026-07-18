-- Notify admins when a standalone task is completed or cancelled
-- Inserts a notification (user_id = NULL) so dashboard shows it to admins

CREATE OR REPLACE FUNCTION public.notify_admin_on_standalone_task_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supervisor_name text;
  v_title text;
  v_status_label text;
BEGIN
  -- Only act when status actually changed to completed or cancelled
  IF (OLD.status IS DISTINCT FROM NEW.status) AND (NEW.status IN ('completed','cancelled')) THEN
    BEGIN
      SELECT coalesce(full_name, email, NEW.supervisor_id::text) INTO v_supervisor_name
      FROM public.users
      WHERE id = NEW.supervisor_id;
    EXCEPTION WHEN OTHERS THEN
      v_supervisor_name := COALESCE(NEW.supervisor_id::text, '');
    END;

    v_title := CASE WHEN NEW.status = 'completed' THEN 'انتهاء مهمة' ELSE 'إلغاء مهمة' END;
    v_status_label := CASE WHEN NEW.status = 'completed' THEN 'مكتملة' ELSE 'ملغاة' END;

    -- Insert broadcast notification for admins (user_id = NULL)
    BEGIN
      INSERT INTO public.notifications (user_id, title, body, meta)
      VALUES (
        NULL,
        v_title || ' — ' || COALESCE(NEW.title, NEW.id::text),
        format('%s قام بتغيير حالة المهمة %s إلى %s', coalesce(v_supervisor_name, 'مشرف'), coalesce(NEW.title::text, NEW.id::text), v_status_label),
        jsonb_build_object('task_id', NEW.id::text, 'status', NEW.status, 'supervisor_id', NEW.supervisor_id::text)
      );
    EXCEPTION WHEN OTHERS THEN
      -- Swallow errors to avoid blocking the update
      NULL;
    END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admin_on_standalone_task_status_change ON public.standalone_tasks;
CREATE TRIGGER trg_notify_admin_on_standalone_task_status_change
  AFTER UPDATE ON public.standalone_tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admin_on_standalone_task_status_change();

-- Fix any existing stored notifications that still include English task status labels.
UPDATE public.notifications
SET body = regexp_replace(body, E'\\bcompleted\\b', 'مكتملة', 'gi')
WHERE body ILIKE '%completed%';

UPDATE public.notifications
SET body = regexp_replace(body, E'\\bcancelled\\b', 'ملغاة', 'gi')
WHERE body ILIKE '%cancelled%';

UPDATE public.notifications
SET title = regexp_replace(title, E'\\bcompleted\\b', 'مكتملة', 'gi')
WHERE title ILIKE '%completed%';

UPDATE public.notifications
SET title = regexp_replace(title, E'\\bcancelled\\b', 'ملغاة', 'gi')
WHERE title ILIKE '%cancelled%';
