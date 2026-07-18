-- Create table for standalone tasks (not linked to contracts)
CREATE TABLE IF NOT EXISTS public.standalone_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  address TEXT,
  client_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  client_name TEXT,
  client_phone TEXT,
  supervisor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  task_date DATE NOT NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','completed','cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_standalone_tasks_supervisor ON public.standalone_tasks(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_standalone_tasks_date ON public.standalone_tasks(task_date);

-- Enable RLS (policies can be added as needed)
ALTER TABLE public.standalone_tasks ENABLE ROW LEVEL SECURITY;

-- Admin policy: admins have full access
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'standalone_tasks' AND policyname = 'admin_all_standalone_tasks'
  ) THEN
    CREATE POLICY admin_all_standalone_tasks ON public.standalone_tasks
      FOR ALL TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_roles ur
          JOIN public.roles r ON r.id = ur.role_id
          WHERE ur.user_id = auth.uid() AND r.name = 'admin'
        )
      );
  END IF;
END $$;

-- Supervisor policy: supervisors can view and update tasks assigned to them
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'standalone_tasks' AND policyname = 'supervisor_view_assigned_tasks'
  ) THEN
    CREATE POLICY supervisor_view_assigned_tasks ON public.standalone_tasks
      FOR SELECT TO authenticated
      USING (
        (supervisor_id = auth.uid() AND EXISTS (
          SELECT 1 FROM public.user_roles ur
          JOIN public.roles r ON r.id = ur.role_id
          WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin')
        ))
      );
  END IF;
END $$;

-- Supervisor policy: supervisors can update status of tasks assigned to them
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'standalone_tasks' AND policyname = 'supervisor_update_assigned_tasks'
  ) THEN
    CREATE POLICY supervisor_update_assigned_tasks ON public.standalone_tasks
      FOR UPDATE TO authenticated
      USING (
        (supervisor_id = auth.uid() AND EXISTS (
          SELECT 1 FROM public.user_roles ur
          JOIN public.roles r ON r.id = ur.role_id
          WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin')
        ))
      )
      WITH CHECK (
        (supervisor_id = auth.uid() AND EXISTS (
          SELECT 1 FROM public.user_roles ur
          JOIN public.roles r ON r.id = ur.role_id
          WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin')
        ))
      );
  END IF;
END $$;

-- Grants
GRANT ALL ON public.standalone_tasks TO service_role;
GRANT ALL ON public.standalone_tasks TO authenticated;

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_standalone_tasks_updated ON public.standalone_tasks;
CREATE TRIGGER trg_standalone_tasks_updated BEFORE UPDATE ON public.standalone_tasks
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
