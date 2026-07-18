-- =============================================================
-- Push Notifications: device tokens + line assignment trigger
-- =============================================================
-- Prerequisites (run once in Supabase SQL editor before applying):
--
--   SELECT pg_catalog.set_config(
--     'app.settings.edge_function_url',
--     'https://<your-project-ref>.supabase.co',
--     false
--   );
--   SELECT pg_catalog.set_config(
--     'app.settings.notification_secret',
--     '<your-random-secret-min-32-chars>',
--     false
--   );
--
-- Also persist them across restarts:
--   ALTER DATABASE postgres
--     SET "app.settings.edge_function_url" = 'https://<your-project-ref>.supabase.co';
--   ALTER DATABASE postgres
--     SET "app.settings.notification_secret" = '<your-random-secret-min-32-chars>';
-- =============================================================

-- 1. Enable pg_net for outbound HTTP from PostgreSQL
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Device tokens table ----------------------------------------
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token       TEXT        NOT NULL,
    platform    TEXT        NOT NULL CHECK (platform IN ('android', 'ios')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id
    ON public.device_tokens (user_id);

-- Table-level permissions (required alongside RLS policies)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_tokens TO authenticated;
GRANT SELECT ON public.device_tokens TO service_role;

-- Row-level security: each user manages only their own token
-- Four separate policies are required — a single FOR ALL policy breaks upserts.
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "device_tokens_user_manage" ON public.device_tokens;
DROP POLICY IF EXISTS "device_tokens_select"      ON public.device_tokens;
DROP POLICY IF EXISTS "device_tokens_insert"      ON public.device_tokens;
DROP POLICY IF EXISTS "device_tokens_update"      ON public.device_tokens;
DROP POLICY IF EXISTS "device_tokens_delete"      ON public.device_tokens;

CREATE POLICY "device_tokens_select"
    ON public.device_tokens FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "device_tokens_insert"
    ON public.device_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "device_tokens_update"
    ON public.device_tokens FOR UPDATE
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "device_tokens_delete"
    ON public.device_tokens FOR DELETE
    USING (auth.uid() = user_id);

-- 3. Auto-update updated_at on token refresh --------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS device_tokens_set_updated_at ON public.device_tokens;
CREATE TRIGGER device_tokens_set_updated_at
    BEFORE UPDATE ON public.device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- 4. Private config table (used instead of ALTER DATABASE which is blocked on Supabase)
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.app_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Populate with your project values (run manually or via migration):
-- INSERT INTO private.app_config (key, value) VALUES
--   ('edge_function_url',   'https://<ref>.supabase.co'),
--   ('notification_secret', '<your-32-char-secret>')
-- ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 5. Trigger: notify supervisor when a line is assigned ---------
CREATE OR REPLACE FUNCTION public.notify_on_line_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url       TEXT;
    v_secret    TEXT;
    v_line_name TEXT;
BEGIN
    IF (OLD.assigned_line_id IS DISTINCT FROM NEW.assigned_line_id)
       AND NEW.assigned_line_id IS NOT NULL
    THEN
        SELECT name INTO v_line_name
        FROM public.geographic_lines
        WHERE id = NEW.assigned_line_id;

        -- 1. Always store in-app notification (guaranteed delivery)
        BEGIN
            INSERT INTO public.notifications (user_id, title, body, meta)
            VALUES (
                NEW.id,
                'تعيين خط جديد',
                'تم تعيينك على خط: ' || COALESCE(v_line_name, 'خط جديد'),
                jsonb_build_object(
                    'type',    'line_assigned',
                    'line_id', NEW.assigned_line_id::text
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
                                   'supervisorId', NEW.id::text,
                                   'lineId',       NEW.assigned_line_id::text
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
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_line_assigned ON public.users;
CREATE TRIGGER on_line_assigned
    AFTER UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_line_assignment();
