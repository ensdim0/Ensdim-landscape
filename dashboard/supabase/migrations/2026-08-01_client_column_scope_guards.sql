-- Security fix: RLS policies "Clients update own guard info" (contracts) and
-- "Client confirm gateway payment" / "Client confirm standalone gateway payment"
-- (contract_payments / standalone_task_payments) only check ROW ownership
-- (user_id = auth.uid() / tenant_id = current_tenant_id()). They don't
-- restrict which COLUMNS a client may change, and the underlying table-wide
-- `GRANT ... UPDATE ON ALL TABLES ... TO authenticated` (full_rebuild.sql)
-- is additive on top of the later column-scoped grants — so today a client
-- calling PostgREST directly (bypassing the app UI) can update ANY column on
-- their own contract (status, total_value, dates) or falsify a payment's
-- `amount` while marking it "paid".
--
-- Postgres RLS is row-scoped, not column-scoped, and admin + client share the
-- same `authenticated` DB role — so column-level GRANTs can't tell them apart
-- either. The standard fix is a BEFORE UPDATE trigger that diffs OLD vs NEW
-- and rejects changes to any column outside an explicit allow-list, mirroring
-- the existing enforce_contract_payment_limit() trigger pattern. Admins and
-- internal service-role calls (edge functions using SUPABASE_SERVICE_ROLE_KEY)
-- are exempt — they're already gated by is_admin() / their own server-side
-- auth checks.

-- ═══════════════════════════════════════════════════════════════════════
-- contracts: clients may only touch contract_user_name / contract_user_phone
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.enforce_client_contract_guard_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  allowed_keys text[] := ARRAY['contract_user_name', 'contract_user_phone'];
BEGIN
  IF auth.role() = 'service_role' OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF (to_jsonb(NEW) - allowed_keys) IS DISTINCT FROM (to_jsonb(OLD) - allowed_keys) THEN
    RAISE EXCEPTION 'not_allowed: clients may only update guard info' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_client_contract_guard_columns ON public.contracts;
CREATE TRIGGER trg_enforce_client_contract_guard_columns
  BEFORE UPDATE ON public.contracts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_contract_guard_columns();

-- ═══════════════════════════════════════════════════════════════════════
-- contract_payments / standalone_task_payments: clients may only transition
-- their own pending payment to paid, touching gateway_status/payment_method/
-- payment_date/due_date — never amount, contract_id/task_id, or tenant_id.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.enforce_client_payment_confirmation_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  allowed_keys text[] := ARRAY['gateway_status', 'payment_method', 'payment_date', 'due_date'];
BEGIN
  IF auth.role() = 'service_role' OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF OLD.gateway_status IS DISTINCT FROM 'pending' OR NEW.gateway_status IS DISTINCT FROM 'paid' THEN
    RAISE EXCEPTION 'not_allowed: clients may only confirm their own pending payment' USING ERRCODE = '42501';
  END IF;

  IF (to_jsonb(NEW) - allowed_keys) IS DISTINCT FROM (to_jsonb(OLD) - allowed_keys) THEN
    RAISE EXCEPTION 'not_allowed: clients may only confirm their own pending payment' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_client_contract_payment_columns ON public.contract_payments;
CREATE TRIGGER trg_enforce_client_contract_payment_columns
  BEFORE UPDATE ON public.contract_payments
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_payment_confirmation_columns();

DROP TRIGGER IF EXISTS trg_enforce_client_standalone_payment_columns ON public.standalone_task_payments;
CREATE TRIGGER trg_enforce_client_standalone_payment_columns
  BEFORE UPDATE ON public.standalone_task_payments
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_payment_confirmation_columns();
