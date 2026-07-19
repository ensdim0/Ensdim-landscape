-- Multi-tenant SaaS conversion — per-tenant UPayments merchant accounts.
--
-- Today every tenant would share one UPayments merchant account (global env
-- vars + a single `private.app_config` row). Per the decision to keep each
-- company's client payments flowing into THEIR OWN UPayments account, this
-- adds `private.tenant_payment_settings` and makes the get_upayments_*
-- RPCs tenant-aware.
--
-- Backward compatible on purpose: every lookup here falls back to the
-- existing global env vars / private.app_config values whenever a tenant
-- has no row (or a null column) in tenant_payment_settings — so Ensdim's
-- current production UPayments setup keeps working completely unchanged
-- with zero manual reconfiguration. A NEW tenant only gets its own
-- isolated gateway once someone explicitly configures a row for it (via
-- `set_tenant_payment_credentials` below, or a direct SQL insert during
-- manual onboarding).

CREATE TABLE IF NOT EXISTS private.tenant_payment_settings (
  tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
  upayments_api_token text,
  upayments_nwl_token text,
  upayments_gateway_src text NOT NULL DEFAULT 'cc',
  upayments_webhook_secret text,
  upayments_return_url text,
  upayments_cancel_url text,
  upayments_fee_amount numeric,
  upayments_sandbox_mode boolean,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_tenant_payment_settings_updated ON private.tenant_payment_settings;
CREATE TRIGGER trg_tenant_payment_settings_updated
  BEFORE UPDATE ON private.tenant_payment_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Tenant-aware fee amount: p_tenant_id NULL keeps the old global behavior
-- (so anything that still calls this with no args is unaffected).
CREATE OR REPLACE FUNCTION public.get_upayments_fee_amount(p_tenant_id uuid DEFAULT NULL)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_amount numeric;
  v_value  text;
BEGIN
  IF p_tenant_id IS NOT NULL THEN
    SELECT upayments_fee_amount INTO v_amount FROM private.tenant_payment_settings WHERE tenant_id = p_tenant_id;
    IF v_amount IS NOT NULL THEN
      RETURN v_amount;
    END IF;
  END IF;

  SELECT value INTO v_value FROM private.app_config WHERE key = 'upayments_fee_amount_kwd';
  RETURN COALESCE(v_value::NUMERIC, 0.13);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_upayments_fee_amount(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_upayments_sandbox_mode(p_tenant_id uuid DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sandbox boolean;
  v_value   text;
BEGIN
  IF p_tenant_id IS NOT NULL THEN
    SELECT upayments_sandbox_mode INTO v_sandbox FROM private.tenant_payment_settings WHERE tenant_id = p_tenant_id;
    IF v_sandbox IS NOT NULL THEN
      RETURN v_sandbox;
    END IF;
  END IF;

  SELECT value INTO v_value FROM private.app_config WHERE key = 'upayments_sandbox_mode';
  RETURN COALESCE(v_value::BOOLEAN, TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_upayments_sandbox_mode(uuid) TO authenticated, service_role;

-- SET functions now write to the CALLING admin's own tenant row instead of
-- the old global app_config — the "بوابة الدفع" toggle in the dashboard
-- keeps calling these with the same signature (no frontend change needed),
-- it just becomes per-tenant automatically.
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

  INSERT INTO private.tenant_payment_settings (tenant_id, upayments_fee_amount)
  VALUES (public.current_tenant_id(), p_amount)
  ON CONFLICT (tenant_id) DO UPDATE SET upayments_fee_amount = EXCLUDED.upayments_fee_amount;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_upayments_fee_amount(NUMERIC) TO authenticated;

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

  INSERT INTO private.tenant_payment_settings (tenant_id, upayments_sandbox_mode)
  VALUES (public.current_tenant_id(), p_sandbox)
  ON CONFLICT (tenant_id) DO UPDATE SET upayments_sandbox_mode = EXCLUDED.upayments_sandbox_mode;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_upayments_sandbox_mode(BOOLEAN) TO authenticated;

-- Full credential set (API token, webhook secret, etc.) — service_role only,
-- these are actual secrets and must never be readable by a regular client.
CREATE OR REPLACE FUNCTION public.get_tenant_payment_credentials(p_tenant_id uuid)
RETURNS TABLE(
  api_token text, nwl_token text, gateway_src text,
  webhook_secret text, return_url text, cancel_url text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT upayments_api_token, upayments_nwl_token, upayments_gateway_src,
         upayments_webhook_secret, upayments_return_url, upayments_cancel_url
  FROM private.tenant_payment_settings
  WHERE tenant_id = p_tenant_id;
$$;

REVOKE ALL ON FUNCTION public.get_tenant_payment_credentials(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_tenant_payment_credentials(uuid) TO service_role;

-- Lets a tenant's own admin configure their UPayments merchant credentials
-- (no dashboard UI for this yet — call directly via supabase.rpc(...), or
-- upsert `private.tenant_payment_settings` straight from the SQL editor
-- during manual onboarding).
CREATE OR REPLACE FUNCTION public.set_tenant_payment_credentials(
  p_api_token text,
  p_nwl_token text,
  p_gateway_src text,
  p_webhook_secret text,
  p_return_url text,
  p_cancel_url text
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'only admins can change this setting';
  END IF;

  INSERT INTO private.tenant_payment_settings (
    tenant_id, upayments_api_token, upayments_nwl_token, upayments_gateway_src,
    upayments_webhook_secret, upayments_return_url, upayments_cancel_url
  )
  VALUES (
    public.current_tenant_id(), p_api_token, p_nwl_token, COALESCE(p_gateway_src, 'cc'),
    p_webhook_secret, p_return_url, p_cancel_url
  )
  ON CONFLICT (tenant_id) DO UPDATE SET
    upayments_api_token = EXCLUDED.upayments_api_token,
    upayments_nwl_token = EXCLUDED.upayments_nwl_token,
    upayments_gateway_src = EXCLUDED.upayments_gateway_src,
    upayments_webhook_secret = EXCLUDED.upayments_webhook_secret,
    upayments_return_url = EXCLUDED.upayments_return_url,
    upayments_cancel_url = EXCLUDED.upayments_cancel_url;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_tenant_payment_credentials(text, text, text, text, text, text) TO authenticated;
