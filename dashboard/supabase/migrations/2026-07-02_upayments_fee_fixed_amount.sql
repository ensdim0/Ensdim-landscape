-- Switch the UPayments commission from a percentage-of-amount fee to a flat
-- per-payment amount (accounting-only figure, mirrors the old fee_pct setting).

-- Seed default fixed fee (0.13 KWD) so behavior is defined immediately after this migration.
INSERT INTO private.app_config (key, value) VALUES ('upayments_fee_amount_kwd', '0.13')
ON CONFLICT (key) DO NOTHING;

-- Read the current fixed fee amount (KWD).
-- Callable by any authenticated user (harmless to read; edge functions + dashboard both need it).
CREATE OR REPLACE FUNCTION public.get_upayments_fee_amount()
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_value TEXT;
BEGIN
  SELECT value INTO v_value FROM private.app_config WHERE key = 'upayments_fee_amount_kwd';
  RETURN COALESCE(v_value::NUMERIC, 0.13);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_upayments_fee_amount() TO authenticated;

-- Update the fixed fee amount — admin only.
CREATE OR REPLACE FUNCTION public.set_upayments_fee_amount(p_amount NUMERIC)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'only admins can change this setting';
  END IF;
  IF p_amount IS NULL OR p_amount < 0 OR p_amount > 1000 THEN
    RAISE EXCEPTION 'fee amount must be between 0 and 1000';
  END IF;

  INSERT INTO private.app_config (key, value) VALUES ('upayments_fee_amount_kwd', p_amount::TEXT)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_upayments_fee_amount(NUMERIC) TO authenticated;

-- Percentage-based fee setting is replaced by the fixed-amount setting above.
DROP FUNCTION IF EXISTS public.get_upayments_fee_pct();
DROP FUNCTION IF EXISTS public.set_upayments_fee_pct(NUMERIC);
DELETE FROM private.app_config WHERE key = 'upayments_fee_pct';
