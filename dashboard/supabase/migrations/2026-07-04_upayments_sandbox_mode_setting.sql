-- Seed default mode so behavior is unchanged immediately after this migration
-- (gateway currently runs on the UPAYMENTS_SANDBOX env-var fallback, which is sandbox).
INSERT INTO private.app_config (key, value) VALUES ('upayments_sandbox_mode', 'true')
ON CONFLICT (key) DO NOTHING;

-- Read whether UPayments should run in sandbox (true) or production (false) mode.
-- Callable by any authenticated user (harmless to read; edge functions + dashboard both need it).
CREATE OR REPLACE FUNCTION public.get_upayments_sandbox_mode()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_value TEXT;
BEGIN
  SELECT value INTO v_value FROM private.app_config WHERE key = 'upayments_sandbox_mode';
  RETURN COALESCE(v_value::BOOLEAN, TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_upayments_sandbox_mode() TO authenticated;

-- Switch between sandbox and production — admin only.
CREATE OR REPLACE FUNCTION public.set_upayments_sandbox_mode(p_sandbox BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'only admins can change this setting';
  END IF;
  IF p_sandbox IS NULL THEN
    RAISE EXCEPTION 'p_sandbox must not be null';
  END IF;

  INSERT INTO private.app_config (key, value) VALUES ('upayments_sandbox_mode', p_sandbox::TEXT)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_upayments_sandbox_mode(BOOLEAN) TO authenticated;
