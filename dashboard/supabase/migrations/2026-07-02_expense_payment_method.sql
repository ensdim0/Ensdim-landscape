-- Track which account/payment method an expense or vehicle expense was paid through.
-- Nullable: legacy rows predate this feature and must not be forced to a default
-- (a false "cash" default would misrepresent real payment history).

ALTER TABLE company_expenses ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE vehicle_expenses ADD COLUMN IF NOT EXISTS payment_method TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'company_expenses_payment_method_check') THEN
    ALTER TABLE company_expenses
      ADD CONSTRAINT company_expenses_payment_method_check
      CHECK (payment_method IS NULL OR payment_method IN ('cash','transfer','cheque','card','gateway'));
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vehicle_expenses_payment_method_check') THEN
    ALTER TABLE vehicle_expenses
      ADD CONSTRAINT vehicle_expenses_payment_method_check
      CHECK (payment_method IS NULL OR payment_method IN ('cash','transfer','cheque','card','gateway'));
  END IF;
END$$;
