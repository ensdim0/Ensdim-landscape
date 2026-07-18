-- Contract Payments table
CREATE TABLE IF NOT EXISTS contract_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'cash',
    transfer_image_url TEXT,
    notes TEXT,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookups by contract
CREATE INDEX IF NOT EXISTS idx_contract_payments_contract_id ON contract_payments(contract_id);

-- RLS
ALTER TABLE contract_payments ENABLE ROW LEVEL SECURITY;

-- Grant access
GRANT SELECT, INSERT, UPDATE, DELETE ON contract_payments TO authenticated;

-- Drop old policies if exist
DROP POLICY IF EXISTS "Admins can manage contract payments" ON contract_payments;
DROP POLICY IF EXISTS "Admins full access contract_payments" ON contract_payments;
DROP POLICY IF EXISTS "Clients can view own contract payments" ON contract_payments;

CREATE POLICY "Admins full access contract_payments"
ON contract_payments FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "Clients can view own contract payments"
ON contract_payments FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM contracts c
        WHERE c.id = contract_payments.contract_id
        AND c.user_id = auth.uid()
    )
);

-- Storage bucket for payment transfer images
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-images', 'payment-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Authenticated users can upload payment images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view payment images" ON storage.objects;

CREATE POLICY "Authenticated users can upload payment images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'payment-images');

CREATE POLICY "Anyone can view payment images"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'payment-images');
