-- UPayments gateway integration: add scheduling + gateway fields to payment tables

-- ── contract_payments ────────────────────────────────────────────────────────
ALTER TABLE contract_payments
  ADD COLUMN IF NOT EXISTS due_date                 DATE,
  ADD COLUMN IF NOT EXISTS payment_gateway_url      TEXT,
  ADD COLUMN IF NOT EXISTS payment_gateway_order_id TEXT,
  ADD COLUMN IF NOT EXISTS gateway_status           TEXT
    CHECK (gateway_status IN ('pending','paid','failed','cancelled')),
  ADD COLUMN IF NOT EXISTS gateway_fee_amount       NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS receipt_url              TEXT;

-- ── standalone_task_payments ─────────────────────────────────────────────────
ALTER TABLE standalone_task_payments
  ADD COLUMN IF NOT EXISTS due_date                 DATE,
  ADD COLUMN IF NOT EXISTS payment_gateway_url      TEXT,
  ADD COLUMN IF NOT EXISTS payment_gateway_order_id TEXT,
  ADD COLUMN IF NOT EXISTS gateway_status           TEXT
    CHECK (gateway_status IN ('pending','paid','failed','cancelled')),
  ADD COLUMN IF NOT EXISTS gateway_fee_amount       NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS receipt_url              TEXT;

-- Indexes for cron and webhook lookups
CREATE INDEX IF NOT EXISTS idx_contract_payments_due
  ON contract_payments(due_date)
  WHERE gateway_status IS NULL OR gateway_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_contract_payments_order
  ON contract_payments(payment_gateway_order_id)
  WHERE payment_gateway_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_standalone_payments_due
  ON standalone_task_payments(due_date)
  WHERE gateway_status IS NULL OR gateway_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_standalone_payments_order
  ON standalone_task_payments(payment_gateway_order_id)
  WHERE payment_gateway_order_id IS NOT NULL;

-- ── Storage bucket for payment receipt images ─────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-receipts', 'payment-receipts', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Client upload own receipt" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated view receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update receipts" ON storage.objects;

CREATE POLICY "Client upload own receipt"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'payment-receipts');

CREATE POLICY "Authenticated view receipts"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'payment-receipts');

CREATE POLICY "Authenticated update receipts"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'payment-receipts');
