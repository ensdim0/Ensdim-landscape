-- Prevent contract_payments from ever summing to more than the contract's
-- total_value. Counts every payment that still represents a live financial
-- commitment (paid, pending gateway, or scheduled) and only excludes rows
-- that will never be collected (gateway_status IN ('failed','cancelled')).
-- This is a last-line-of-defense guard behind the dashboard's own client-side
-- validation, so it also protects direct SQL/RPC writes (e.g. the UPayments
-- webhook and confirm-gateway-payment RPC).

CREATE OR REPLACE FUNCTION public.enforce_contract_payment_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_value  NUMERIC;
  v_active_sum   NUMERIC;
BEGIN
  IF NEW.gateway_status IN ('failed', 'cancelled') THEN
    RETURN NEW;
  END IF;

  SELECT total_value INTO v_total_value
  FROM contracts
  WHERE id = NEW.contract_id;

  IF v_total_value IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_active_sum
  FROM contract_payments
  WHERE contract_id = NEW.contract_id
    AND id <> NEW.id
    AND (gateway_status IS NULL OR gateway_status NOT IN ('failed', 'cancelled'));

  IF v_active_sum + NEW.amount > v_total_value + 0.001 THEN
    RAISE EXCEPTION 'الدفعات تتجاوز قيمة العقد المتبقية (المتبقي: %)', (v_total_value - v_active_sum)
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_contract_payment_limit ON contract_payments;

CREATE TRIGGER trg_enforce_contract_payment_limit
  BEFORE INSERT OR UPDATE ON contract_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_contract_payment_limit();
