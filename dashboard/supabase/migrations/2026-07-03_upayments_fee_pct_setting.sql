-- Seed default fee so behavior is unchanged immediately after this migration.
INSERT INTO private.app_config (key, value) VALUES ('upayments_fee_pct', '0.025')
ON CONFLICT (key) DO NOTHING;

-- Read the current fee percentage (fraction, e.g. 0.025 = 2.5%).
-- Callable by any authenticated user (harmless to read; edge functions + dashboard both need it).
CREATE OR REPLACE FUNCTION public.get_upayments_fee_pct()
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_value TEXT;
BEGIN
  SELECT value INTO v_value FROM private.app_config WHERE key = 'upayments_fee_pct';
  RETURN COALESCE(v_value::NUMERIC, 0.025);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_upayments_fee_pct() TO authenticated;

-- Update the fee percentage — admin only.
CREATE OR REPLACE FUNCTION public.set_upayments_fee_pct(p_pct NUMERIC)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'only admins can change this setting';
  END IF;
  IF p_pct IS NULL OR p_pct < 0 OR p_pct > 1 THEN
    RAISE EXCEPTION 'fee percentage must be between 0 and 1';
  END IF;

  INSERT INTO private.app_config (key, value) VALUES ('upayments_fee_pct', p_pct::TEXT)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_upayments_fee_pct(NUMERIC) TO authenticated;
