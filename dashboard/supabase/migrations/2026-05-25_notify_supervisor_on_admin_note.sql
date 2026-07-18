-- Notify the assigned supervisor when an admin adds a note on a visit.

CREATE OR REPLACE FUNCTION public.fn_notify_supervisor_on_admin_note()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_supervisor_id UUID;
    v_line_id       UUID;
    v_admin_name    TEXT;
    v_url           TEXT;
    v_secret        TEXT;
BEGIN
    -- Only notify when the note is created by an admin (roles via user_roles/roles tables)
    IF NOT EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = NEW.created_by AND r.name = 'admin'
    ) THEN
        RETURN NEW;
    END IF;

    -- Resolve the line for this contract (zone_id direct or via block_id → zone)
    SELECT COALESCE(zd.line_id, zb.line_id)
    INTO v_line_id
    FROM public.contracts c
    LEFT JOIN public.zones  zd ON zd.id = c.zone_id
    LEFT JOIN public.blocks b  ON b.id  = c.block_id
    LEFT JOIN public.zones  zb ON zb.id = b.zone_id
    WHERE c.id = NEW.contract_id;

    IF v_line_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Find the supervisor assigned to this line
    SELECT id INTO v_supervisor_id
    FROM public.users
    WHERE assigned_line_id = v_line_id
      AND id != COALESCE(NEW.created_by, '00000000-0000-0000-0000-000000000000'::uuid)
    LIMIT 1;

    IF v_supervisor_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Admin display name for the notification body
    SELECT COALESCE(full_name, email, 'المسؤول') INTO v_admin_name
    FROM public.users WHERE id = NEW.created_by;

    -- 1. In-app notification (guaranteed delivery via Realtime)
    BEGIN
        INSERT INTO public.notifications (user_id, title, body, meta)
        VALUES (
            v_supervisor_id,
            'ملاحظة جديدة على زيارة',
            v_admin_name || ' أضاف ملاحظة على إحدى زياراتك',
            jsonb_build_object(
                'type',        'supervisor_note',
                'visit_id',    NEW.visit_id::text,
                'contract_id', NEW.contract_id::text,
                'note_id',     NEW.id::text,
                'admin_name',  v_admin_name
            )
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 2. FCM push notification (best effort, requires pg_net)
    BEGIN
        SELECT value INTO v_url    FROM private.app_config WHERE key = 'edge_function_url';
        SELECT value INTO v_secret FROM private.app_config WHERE key = 'notification_secret';

        IF v_url IS NOT NULL AND v_secret IS NOT NULL THEN
            PERFORM net.http_post(
                url     := v_url || '/functions/v1/send-push-notification',
                body    := jsonb_build_object(
                               'supervisorId', v_supervisor_id::text,
                               'visitId',      NEW.visit_id::text,
                               'contractId',   NEW.contract_id::text,
                               'noteType',     'supervisor_note'
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

DROP TRIGGER IF EXISTS trg_notify_supervisor_on_admin_note ON public.supervisor_notes;
CREATE TRIGGER trg_notify_supervisor_on_admin_note
    AFTER INSERT ON public.supervisor_notes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_supervisor_on_admin_note();
