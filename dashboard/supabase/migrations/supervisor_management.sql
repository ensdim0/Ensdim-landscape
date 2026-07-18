-- ╔══════════════════════════════════════════════════════════════════╗
-- ║     Supervisors Management - DB Migration                      ║
-- ║     Ensures contract_tasks table & supervisor fields exist     ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Ensure contract_tasks table exists ──
CREATE TABLE IF NOT EXISTS public.contract_tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'verified', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ── 2. Create indexes for performance ──
CREATE INDEX IF NOT EXISTS idx_contract_tasks_contract_id ON public.contract_tasks(contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_tasks_status ON public.contract_tasks(status);
CREATE INDEX IF NOT EXISTS idx_contract_tasks_month ON public.contract_tasks(month);

-- ── 3. Add supervisor assignment columns to public.users ──
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'assigned_line_id'
    ) THEN
        ALTER TABLE public.users 
        ADD COLUMN assigned_line_id UUID REFERENCES public.geographic_lines(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'assignment_start_date'
    ) THEN
        ALTER TABLE public.users ADD COLUMN assignment_start_date DATE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'assignment_end_date'
    ) THEN
        ALTER TABLE public.users ADD COLUMN assignment_end_date DATE;
    END IF;
END $$;

-- ── 4. Enable RLS on contract_tasks ──
ALTER TABLE public.contract_tasks ENABLE ROW LEVEL SECURITY;

-- ── 5. RLS Policies ──
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'contract_tasks' AND policyname = 'admin_all_contract_tasks'
  ) THEN
    CREATE POLICY admin_all_contract_tasks ON public.contract_tasks
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
    SELECT 1 FROM pg_policies WHERE tablename = 'contract_tasks' AND policyname = 'supervisor_read_contract_tasks'
  ) THEN
    CREATE POLICY supervisor_read_contract_tasks ON public.contract_tasks
      FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.users u
          JOIN public.zones z ON z.line_id = u.assigned_line_id
          JOIN public.contracts c ON c.zone_id = z.id
          WHERE u.id = auth.uid() AND c.id = contract_tasks.contract_id
        )
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'contract_tasks' AND policyname = 'supervisor_update_contract_tasks'
  ) THEN
    CREATE POLICY supervisor_update_contract_tasks ON public.contract_tasks
      FOR UPDATE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.users u
          JOIN public.zones z ON z.line_id = u.assigned_line_id
          JOIN public.contracts c ON c.zone_id = z.id
          WHERE u.id = auth.uid() AND c.id = contract_tasks.contract_id
        )
      );
  END IF;
END $$;

-- ── 6. Recreate users_view with assignment fields & proper role join ──
DROP VIEW IF EXISTS public.users_view;

CREATE VIEW public.users_view AS
SELECT 
    u.id,
    u.full_name AS "fullName",
    u.email,
  u.phone,
    r.name AS role,
    u.assigned_line_id AS "assignedLineId",
    u.assignment_start_date AS "assignmentStartDate",
    u.assignment_end_date AS "assignmentEndDate",
    u.created_at AS "createdAt"
FROM public.users u
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
LEFT JOIN public.roles r ON r.id = ur.role_id
WHERE u.deleted_at IS NULL;

GRANT SELECT ON public.users_view TO authenticated;
GRANT SELECT ON public.users_view TO anon;

-- ── 7. Fix table permissions for service_role (used by Edge Functions) ──
GRANT ALL ON public.users TO service_role;
GRANT ALL ON public.roles TO service_role;
GRANT ALL ON public.user_roles TO service_role;
GRANT ALL ON public.contract_tasks TO service_role;
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.roles TO authenticated;
GRANT ALL ON public.user_roles TO authenticated;

-- ── 8. Ensure roles are seeded ──
INSERT INTO public.roles (name) VALUES
  ('admin'),
  ('supervisor'),
  ('client')
ON CONFLICT (name) DO NOTHING;

-- ── Done! Run this in Supabase SQL Editor. ──
