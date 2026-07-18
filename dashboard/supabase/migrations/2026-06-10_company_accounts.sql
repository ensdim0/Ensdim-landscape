-- Payment status/method directly on standalone tasks
ALTER TABLE standalone_tasks ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid'));
ALTER TABLE standalone_tasks ADD COLUMN IF NOT EXISTS payment_method TEXT;

-- Standalone task payments (mirrors contract_payments)
CREATE TABLE IF NOT EXISTS standalone_task_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES standalone_tasks(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'cash',
    notes TEXT,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE standalone_task_payments ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON standalone_task_payments TO authenticated;

DROP POLICY IF EXISTS "Admins manage standalone task payments" ON standalone_task_payments;

CREATE POLICY "Admins manage standalone task payments"
    ON standalone_task_payments
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Company expenses (salary / rent / marketing / misc)
CREATE TABLE IF NOT EXISTS company_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL CHECK (category IN ('salary', 'rent', 'marketing', 'misc')),
    name TEXT NOT NULL,
    description TEXT,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    note TEXT,
    worker_id UUID REFERENCES workers(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE company_expenses ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON company_expenses TO authenticated;

DROP POLICY IF EXISTS "Admins manage company expenses" ON company_expenses;

CREATE POLICY "Admins manage company expenses"
    ON company_expenses
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
