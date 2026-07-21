-- Security fix: get_upayments_fee_amount(p_tenant_id) and
-- get_upayments_sandbox_mode(p_tenant_id) (2026-07-23_tenant_payment_settings.sql)
-- are GRANTed to `authenticated` and trust the caller-supplied p_tenant_id with
-- no check that it matches the caller's own tenant. Any authenticated user of
-- Company A who knows/guesses Company B's tenant UUID can read Company B's fee
-- amount and sandbox-mode flag via supabase.rpc(...) directly.
--
-- create-upayment-charge legitimately needs to look up an ARBITRARY tenant's
-- settings (it runs as service_role, not on behalf of one specific tenant), so
-- the fix isn't to drop the parameter — it's to only trust it when the caller
-- is service_role, matching the pattern already used by the newer sibling
-- has_tenant_payment_credentials() (which just always uses current_tenant_id()
-- for the same reason). Function signatures are unchanged, so no edge function
-- redeploy is required for this fix.

CREATE OR REPLACE FUNCTION public.get_upayments_fee_amount(p_tenant_id uuid DEFAULT NULL)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_amount numeric;
  v_value  text;
  v_tenant_id uuid := p_tenant_id;
BEGIN
  IF auth.role() <> 'service_role' THEN
    v_tenant_id := public.current_tenant_id();
  END IF;

  IF v_tenant_id IS NOT NULL THEN
    SELECT upayments_fee_amount INTO v_amount FROM private.tenant_payment_settings WHERE tenant_id = v_tenant_id;
    IF v_amount IS NOT NULL THEN
      RETURN v_amount;
    END IF;
  END IF;

  SELECT value INTO v_value FROM private.app_config WHERE key = 'upayments_fee_amount_kwd';
  RETURN COALESCE(v_value::NUMERIC, 0.13);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_upayments_sandbox_mode(p_tenant_id uuid DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sandbox boolean;
  v_value   text;
  v_tenant_id uuid := p_tenant_id;
BEGIN
  IF auth.role() <> 'service_role' THEN
    v_tenant_id := public.current_tenant_id();
  END IF;

  IF v_tenant_id IS NOT NULL THEN
    SELECT upayments_sandbox_mode INTO v_sandbox FROM private.tenant_payment_settings WHERE tenant_id = v_tenant_id;
    IF v_sandbox IS NOT NULL THEN
      RETURN v_sandbox;
    END IF;
  END IF;

  SELECT value INTO v_value FROM private.app_config WHERE key = 'upayments_sandbox_mode';
  RETURN COALESCE(v_value::BOOLEAN, TRUE);
END;
$$;
