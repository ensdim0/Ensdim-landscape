-- 2026-07-23_tenant_payment_settings.sql replaced get_upayments_fee_amount()
-- and get_upayments_sandbox_mode() with tenant-aware versions that take an
-- optional p_tenant_id (DEFAULT NULL), but never dropped the original
-- zero-arg versions from 2026-07-02 / 2026-07-04. With both overloads
-- present, calling either function with no arguments is ambiguous:
--   "Could not choose the best candidate function between:
--    public.get_upayments_fee_amount(), public.get_upayments_fee_amount(p_tenant_id => uuid)"
-- Drop the stale zero-arg overloads; the tenant-aware versions already
-- preserve the old global behavior when called with no tenant id.
DROP FUNCTION IF EXISTS public.get_upayments_fee_amount();
DROP FUNCTION IF EXISTS public.get_upayments_sandbox_mode();
