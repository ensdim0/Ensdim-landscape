-- Consolidated fix: ensure admins only see their own notifications (plus broadcasts),
-- and stop creating "task assigned" notifications when the assignee is an admin.

-- 1. Notifications SELECT policy: own notifications, or broadcast (user_id IS NULL) for admins.
DROP POLICY IF EXISTS "Authenticated read notifications" ON public.notifications;

CREATE POLICY "Authenticated read notifications"
  ON public.notifications
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR (user_id IS NULL AND public.is_admin())
  );

-- 2. Skip "task assigned" notification when the assignee is an admin account.
CREATE OR REPLACE FUNCTION public.notify_on_standalone_task_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url       TEXT;
    v_secret    TEXT;
    v_new_supervisor UUID;
    v_old_supervisor UUID;
BEGIN
    v_new_supervisor := NEW.supervisor_id;
    v_old_supervisor := CASE WHEN TG_OP = 'UPDATE' THEN OLD.supervisor_id ELSE NULL END;

    IF v_new_supervisor IS NULL THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND (v_old_supervisor IS NOT DISTINCT FROM v_new_supervisor) THEN
        RETURN NEW;
    END IF;

    -- Skip admin accounts: this notification is for supervisors only.
    IF EXISTS (
        SELECT 1 FROM public.user_roles ur
        JOIN public.roles r ON ur.role_id = r.id
        WHERE ur.user_id = v_new_supervisor AND r.name = 'admin'
    ) THEN
        RETURN NEW;
    END IF;

    BEGIN
        INSERT INTO public.notifications (user_id, title, body, meta)
        VALUES (
            v_new_supervisor,
            'مهمة جديدة',
            'تم تعيينك على مهمة: ' || COALESCE(NULLIF(TRIM(NEW.title), ''), 'مهمة جديدة') ||
            CASE WHEN NEW.task_date IS NOT NULL
                 THEN ' – ' || TO_CHAR(NEW.task_date, 'YYYY-MM-DD')
                 ELSE '' END,
            jsonb_build_object(
                'type',    'standalone_task_assigned',
                'task_id', NEW.id::text
            )
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    BEGIN
        SELECT value INTO v_url    FROM private.app_config WHERE key = 'edge_function_url';
        SELECT value INTO v_secret FROM private.app_config WHERE key = 'notification_secret';

        IF v_url IS NOT NULL AND v_secret IS NOT NULL THEN
            PERFORM net.http_post(
                url     := v_url || '/functions/v1/send-push-notification',
                body    := jsonb_build_object(
                               'supervisorId', v_new_supervisor::text,
                               'taskId',       NEW.id::text
                           ),
                headers := jsonb_build_object(
                               'Content-Type',          'application/json',
                               'x-notification-secret', v_secret
                           )
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NEW;
END;
$$;

-- 3. Clean up notifications that don't belong to the admin viewing them
--    (i.e. rows with a non-null user_id different from auth.uid() that an
--     admin previously inserted/received under the old broad policy won't
--     be visible anymore once the policy above is applied — no data deletion needed).

-- 4. Remove any "task assigned" notifications mistakenly sent to admin accounts.
DELETE FROM public.notifications n
WHERE n.meta->>'type' = 'standalone_task_assigned'
  AND EXISTS (
      SELECT 1 FROM public.user_roles ur
      JOIN public.roles r ON ur.role_id = r.id
      WHERE ur.user_id = n.user_id AND r.name = 'admin'
  );
