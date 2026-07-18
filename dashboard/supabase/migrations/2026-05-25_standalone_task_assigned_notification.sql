-- Notify supervisor when a standalone task is assigned to them.
-- Fires on INSERT (task created already assigned) and on UPDATE (supervisor_id changed).

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

    -- Only act when supervisor_id is set and actually changed (or newly inserted with a supervisor)
    IF v_new_supervisor IS NULL THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND (v_old_supervisor IS NOT DISTINCT FROM v_new_supervisor) THEN
        RETURN NEW;
    END IF;

    -- 1. In-app notification (guaranteed delivery)
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

    -- 2. FCM push notification (best effort)
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

DROP TRIGGER IF EXISTS trg_notify_standalone_task_assigned ON public.standalone_tasks;
CREATE TRIGGER trg_notify_standalone_task_assigned
    AFTER INSERT OR UPDATE OF supervisor_id ON public.standalone_tasks
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_standalone_task_assignment();
