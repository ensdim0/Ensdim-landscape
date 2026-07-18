-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Add completion fields to visits table                        ║
-- ║  summary, gps_lat, gps_lng, completed_at                     ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Add summary field for visit closure notes ──
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS summary TEXT;

-- ── 2. Add GPS coordinates captured at visit completion ──
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS gps_lat NUMERIC(10, 7);
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS gps_lng NUMERIC(10, 7);

-- ── 3. Add completion timestamp ──
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- ── 4. Create a visit_photos table for visit-level photos ──
CREATE TABLE IF NOT EXISTS public.visit_photos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  photo_path TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.visit_photos ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_visit_photos_visit_id ON public.visit_photos(visit_id);

-- ── 5. RLS Policies for visit_photos ──
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'visit_photos' AND policyname = 'admin_all_visit_photos'
  ) THEN
    CREATE POLICY admin_all_visit_photos ON public.visit_photos
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
    SELECT 1 FROM pg_policies WHERE tablename = 'visit_photos' AND policyname = 'supervisor_manage_visit_photos'
  ) THEN
    CREATE POLICY supervisor_manage_visit_photos ON public.visit_photos
      FOR ALL TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.users u
          JOIN public.zones z ON z.line_id = u.assigned_line_id
          JOIN public.contracts c ON c.zone_id = z.id
          JOIN public.visits v ON v.contract_id = c.id
          WHERE u.id = auth.uid() AND v.id = visit_photos.visit_id
        )
      );
  END IF;
END $$;

-- ── 6. Grant permissions ──
GRANT ALL ON public.visit_photos TO service_role;
GRANT ALL ON public.visit_photos TO authenticated;

-- ── 7. Add supervisor write policies for visits (INSERT + UPDATE) ──
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'visits' AND policyname = 'supervisor_insert_visits'
  ) THEN
    CREATE POLICY supervisor_insert_visits ON public.visits
      FOR INSERT TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.users u
          JOIN public.zones z ON z.line_id = u.assigned_line_id
          JOIN public.contracts c ON c.zone_id = z.id
          WHERE u.id = auth.uid() AND c.id = visits.contract_id
        )
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'visits' AND policyname = 'supervisor_update_visits'
  ) THEN
    CREATE POLICY supervisor_update_visits ON public.visits
      FOR UPDATE TO authenticated
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

-- ── 8. Add supervisor INSERT policy for task_executions ──
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'task_executions' AND policyname = 'supervisor_insert_task_executions'
  ) THEN
    CREATE POLICY supervisor_insert_task_executions ON public.task_executions
      FOR INSERT TO authenticated
      WITH CHECK (supervisor_id = auth.uid());
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'task_executions' AND policyname = 'supervisor_read_task_executions'
  ) THEN
    CREATE POLICY supervisor_read_task_executions ON public.task_executions
      FOR SELECT TO authenticated
      USING (supervisor_id = auth.uid());
  END IF;
END $$;
