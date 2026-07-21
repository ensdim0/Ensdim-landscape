-- Payment gateway self-service settings — groundwork for multiple providers.
--
-- Per-tenant UPayments credentials already exist (private.tenant_payment_settings,
-- set_tenant_payment_credentials RPC — see 2026-07-23_tenant_payment_settings.sql)
-- but have no dashboard UI yet. This adds:
--   1. A `provider` column so the settings row (and future dashboard UI) can
--      represent which gateway a tenant uses, without a breaking schema
--      change when a second provider (e.g. Stripe) is actually implemented.
--      The CHECK intentionally only allows 'upayments' today — extend it in
--      a follow-up migration once a second provider is real.
--   2. has_tenant_payment_credentials() — lets the dashboard show a
--      "configured / not configured" badge without ever exposing the actual
--      secret (get_tenant_payment_credentials stays service_role-only).

ALTER TABLE private.tenant_payment_settings
  ADD COLUMN IF NOT EXISTS provider text NOT NULL DEFAULT 'upayments';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tenant_payment_settings_provider_check'
  ) THEN
    ALTER TABLE private.tenant_payment_settings
      ADD CONSTRAINT tenant_payment_settings_provider_check CHECK (provider IN ('upayments'));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.has_tenant_payment_credentials()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM private.tenant_payment_settings
    WHERE tenant_id = public.current_tenant_id() AND upayments_api_token IS NOT NULL
  );
$$;

GRANT EXECUTE ON FUNCTION public.has_tenant_payment_credentials() TO authenticated;
