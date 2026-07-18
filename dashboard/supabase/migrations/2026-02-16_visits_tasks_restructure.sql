-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Restructure: Tasks belong to Visits, not directly to Contracts║
-- ║  Contract → Visit → Task                                      ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Ensure visits table exists and has the required columns ──
-- The table may already exist from an earlier migration with different columns.
CREATE TABLE IF NOT EXISTS public.visits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
  visit_date DATE NOT NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add status column if table already existed without it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'visits' AND column_name = 'status'
  ) THEN
    ALTER TABLE public.visits
      ADD COLUMN status TEXT NOT NULL DEFAULT 'planned';
    ALTER TABLE public.visits
      ADD CONSTRAINT visits_status_check CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled'));
  END IF;
END $$;

-- Drop legacy RLS policies that depend on old columns
DROP POLICY IF EXISTS "Supervisors read assigned visits" ON public.visits;

-- Drop legacy columns that are no longer needed
ALTER TABLE public.visits DROP COLUMN IF EXISTS supervisor_id;
ALTER TABLE public.visits DROP COLUMN IF EXISTS gps_lat;
ALTER TABLE public.visits DROP COLUMN IF EXISTS gps_lng;
ALTER TABLE public.visits DROP COLUMN IF EXISTS deleted_at;

-- Ensure visit_date is DATE (old schema used timestamptz)
-- We keep it as-is since timestamptz is compatible; no data loss

-- ── 2. Add visit_id column to contract_tasks ──
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'contract_tasks' AND column_name = 'visit_id'
  ) THEN
    ALTER TABLE public.contract_tasks
      ADD COLUMN visit_id UUID REFERENCES public.visits(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ── 3. Create indexes ──
CREATE INDEX IF NOT EXISTS idx_visits_contract_id ON public.visits(contract_id);
CREATE INDEX IF NOT EXISTS idx_visits_status ON public.visits(status);
CREATE INDEX IF NOT EXISTS idx_visits_visit_date ON public.visits(visit_date);
CREATE INDEX IF NOT EXISTS idx_contract_tasks_visit_id ON public.contract_tasks(visit_id);

-- ── 4. Enable RLS on visits ──
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;

-- ── 5. RLS Policies for visits ──
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'visits' AND policyname = 'admin_all_visits'
  ) THEN
    CREATE POLICY admin_all_visits ON public.visits
      FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
      ));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'visits' AND policyname = 'supervisor_read_visits'
  ) THEN
    CREATE POLICY supervisor_read_visits ON public.visits
      FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.users u
          JOIN public.zones z ON z.line_id = u.assigned_line_id
          JOIN public.contracts c ON c.zone_id = z.id
          WHERE u.id = auth.uid() AND c.id = visits.contract_id
        )
      );
  END IF;
END $$;

-- ── 6. Grant permissions ──
GRANT ALL ON public.visits TO service_role;
GRANT ALL ON public.visits TO authenticated;
GRANT ALL ON public.contract_tasks TO service_role;
GRANT ALL ON public.contract_tasks TO authenticated;

-- ── 7. Updated_at trigger for visits ──
DROP TRIGGER IF EXISTS trg_visits_updated ON public.visits;
CREATE TRIGGER trg_visits_updated BEFORE UPDATE ON public.visits
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
