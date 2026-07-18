-- Workers table for labor/employee cost tracking
CREATE TABLE IF NOT EXISTS workers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  visa_start DATE NOT NULL,
  visa_end DATE NOT NULL,
  salary NUMERIC(10, 3) NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;

-- Drop old wrong policy
DROP POLICY IF EXISTS "admin_full_access_workers" ON workers;

-- Admin full access (matching project pattern)
CREATE POLICY admin_all_workers ON public.workers
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() AND r.name = 'admin'
  ));

-- Grant table-level permissions
GRANT ALL ON public.workers TO service_role;
GRANT ALL ON public.workers TO authenticated;
