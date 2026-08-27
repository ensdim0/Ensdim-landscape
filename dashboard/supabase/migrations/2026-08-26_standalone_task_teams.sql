-- Standalone task teams, checklists, visit lifecycle and payment confirmation.
--
-- Today a standalone_tasks row is assigned to exactly one supervisor
-- (supervisor_id) and has a single status with no sub-items and no
-- start/end visit tracking (that only exists for contract visits, see
-- 2026-02-16_visits_tasks_restructure.sql / 2026-03-12_visit_completion_fields.sql).
-- This migration extends standalone_tasks to support the same "team +
-- checklist + GPS visit lifecycle + payment confirmation" flow that
-- contract visits already have, but for tasks not tied to a contract:
--
--   1. standalone_task_assignees — the "team": one row per person (a
--      supervisor OR a worker) assigned to a task. Replaces supervisor_id
--      as the source of truth for who can act on a task; supervisor_id is
--      kept on standalone_tasks as a legacy/primary-supervisor reference
--      during the transition and is backfilled into this table below.
--   2. standalone_task_items — the checklist entered by the admin at
--      creation time. Ending a visit requires every item to be completed.
--   3. standalone_task_photos — optional photos at visit start/end,
--      reusing the existing `task-photos` storage bucket.
--   4. New columns on standalone_tasks for visit start/end (time + GPS +
--      who) and payment confirmation (when + who), reusing the existing
--      payment_status/payment_method columns as the closing gate.
--   5. Three SECURITY DEFINER RPCs (start/end visit, confirm payment) that
--      perform a single atomic `UPDATE ... WHERE <expected state>` so that
--      two team members acting at the same moment can never both succeed —
--      Postgres row-level locking on the UPDATE resolves the race, not
--      application code. Mirrors the existing confirm_gateway_payment()
--      pattern in 2026-06-18_confirm_gateway_payment_rpc.sql.
--
-- All changes are additive: no existing column is renamed or dropped, and
-- every current standalone_tasks row keeps working unchanged.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. standalone_task_assignees ("the team")
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.standalone_task_assignees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL DEFAULT public.current_tenant_id() REFERENCES public.tenants(id),
  task_id UUID NOT NULL REFERENCES public.standalone_tasks(id) ON DELETE CASCADE,
  supervisor_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  worker_id UUID REFERENCES public.workers(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT standalone_task_assignees_one_person CHECK (
    (supervisor_id IS NOT NULL AND worker_id IS NULL) OR
    (supervisor_id IS NULL AND worker_id IS NOT NULL)
  ),
  -- NULL is distinct-from-NULL for uniqueness purposes in Postgres, so these
  -- only constrain the rows where the respective column is actually set.
  CONSTRAINT standalone_task_assignees_unique_supervisor UNIQUE (task_id, supervisor_id),
  CONSTRAINT standalone_task_assignees_unique_worker UNIQUE (task_id, worker_id)
);

CREATE INDEX IF NOT EXISTS idx_standalone_task_assignees_task ON public.standalone_task_assignees(task_id);
CREATE INDEX IF NOT EXISTS idx_standalone_task_assignees_tenant ON public.standalone_task_assignees(tenant_id);
CREATE INDEX IF NOT EXISTS idx_standalone_task_assignees_supervisor ON public.standalone_task_assignees(supervisor_id) WHERE supervisor_id IS NOT NULL;

ALTER TABLE public.standalone_task_assignees ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.standalone_task_assignees TO service_role;
GRANT ALL ON public.standalone_task_assignees TO authenticated;

DROP POLICY IF EXISTS admin_all_standalone_task_assignees ON public.standalone_task_assignees;
CREATE POLICY admin_all_standalone_task_assignees ON public.standalone_task_assignees
  FOR ALL TO authenticated
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

-- A supervisor on a task's team can see every row of that same team
-- (other supervisors + workers), not just their own row.
DROP POLICY IF EXISTS supervisor_view_own_team ON public.standalone_task_assignees;
CREATE POLICY supervisor_view_own_team ON public.standalone_task_assignees
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees me
      WHERE me.task_id = standalone_task_assignees.task_id
        AND me.supervisor_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. standalone_task_items (the checklist)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.standalone_task_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL DEFAULT public.current_tenant_id() REFERENCES public.tenants(id),
  task_id UUID NOT NULL REFERENCES public.standalone_tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  completed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_standalone_task_items_task ON public.standalone_task_items(task_id);
CREATE INDEX IF NOT EXISTS idx_standalone_task_items_tenant ON public.standalone_task_items(tenant_id);

ALTER TABLE public.standalone_task_items ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.standalone_task_items TO service_role;
GRANT ALL ON public.standalone_task_items TO authenticated;

DROP POLICY IF EXISTS admin_all_standalone_task_items ON public.standalone_task_items;
CREATE POLICY admin_all_standalone_task_items ON public.standalone_task_items
  FOR ALL TO authenticated
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS supervisor_view_task_items ON public.standalone_task_items;
CREATE POLICY supervisor_view_task_items ON public.standalone_task_items
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees sta
      WHERE sta.task_id = standalone_task_items.task_id AND sta.supervisor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS supervisor_update_task_items ON public.standalone_task_items;
CREATE POLICY supervisor_update_task_items ON public.standalone_task_items
  FOR UPDATE TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees sta
      WHERE sta.task_id = standalone_task_items.task_id AND sta.supervisor_id = auth.uid()
    )
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees sta
      WHERE sta.task_id = standalone_task_items.task_id AND sta.supervisor_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. standalone_task_photos (optional visit start/end photos)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.standalone_task_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL DEFAULT public.current_tenant_id() REFERENCES public.tenants(id),
  task_id UUID NOT NULL REFERENCES public.standalone_tasks(id) ON DELETE CASCADE,
  phase TEXT NOT NULL CHECK (phase IN ('start', 'end')),
  photo_path TEXT NOT NULL,
  uploaded_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_standalone_task_photos_task ON public.standalone_task_photos(task_id);
CREATE INDEX IF NOT EXISTS idx_standalone_task_photos_tenant ON public.standalone_task_photos(tenant_id);

ALTER TABLE public.standalone_task_photos ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.standalone_task_photos TO service_role;
GRANT ALL ON public.standalone_task_photos TO authenticated;

DROP POLICY IF EXISTS admin_all_standalone_task_photos ON public.standalone_task_photos;
CREATE POLICY admin_all_standalone_task_photos ON public.standalone_task_photos
  FOR ALL TO authenticated
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS supervisor_view_task_photos ON public.standalone_task_photos;
CREATE POLICY supervisor_view_task_photos ON public.standalone_task_photos
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees sta
      WHERE sta.task_id = standalone_task_photos.task_id AND sta.supervisor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS supervisor_insert_task_photos ON public.standalone_task_photos;
CREATE POLICY supervisor_insert_task_photos ON public.standalone_task_photos
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND uploaded_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees sta
      WHERE sta.task_id = standalone_task_photos.task_id AND sta.supervisor_id = auth.uid()
    )
  );

-- Extend the shared task-photos bucket read policy (originally defined in
-- 2026-04-05_security_hardening.sql, made tenant-scoped by
-- 2026-07-21_multi_tenant_storage.sql) to also recognize standalone task
-- photos. Upload stays open to any authenticated user, as it already is for
-- task_photos/visit_photos — tenant isolation happens on read, by requiring
-- a matching row to exist in one of these tables.
DROP POLICY IF EXISTS "Authenticated read task photos" ON storage.objects;
DROP POLICY IF EXISTS "Tenant scoped read task photos" ON storage.objects;
CREATE POLICY "Tenant scoped read task photos" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'task-photos'
  AND (
    EXISTS (SELECT 1 FROM public.task_photos tp WHERE tp.photo_path = storage.objects.name AND tp.tenant_id = public.current_tenant_id())
    OR EXISTS (SELECT 1 FROM public.visit_photos vp WHERE vp.photo_path = storage.objects.name AND vp.tenant_id = public.current_tenant_id())
    OR EXISTS (SELECT 1 FROM public.standalone_task_photos stp WHERE stp.photo_path = storage.objects.name AND stp.tenant_id = public.current_tenant_id())
  )
);

-- ─────────────────────────────────────────────────────────────────────────
-- 4. standalone_tasks — visit lifecycle + payment confirmation columns
-- ─────────────────────────────────────────────────────────────────────────

ALTER TABLE public.standalone_tasks
  ADD COLUMN IF NOT EXISTS visit_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS visit_started_lat NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS visit_started_lng NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS started_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS visit_ended_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS visit_ended_lat NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS visit_ended_lng NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS ended_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS payment_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_confirmed_by UUID REFERENCES public.users(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.standalone_tasks.visit_started_at IS 'Set by start_standalone_task_visit() when the team starts the on-site visit';
COMMENT ON COLUMN public.standalone_tasks.visit_ended_at IS 'Set by end_standalone_task_visit() once all checklist items are completed';
COMMENT ON COLUMN public.standalone_tasks.payment_confirmed_at IS 'Set by confirm_standalone_task_payment(); task is only fully closed once this is set (status=completed AND payment_status=paid)';

-- ─────────────────────────────────────────────────────────────────────────
-- 5. Backfill: give every existing assigned task a matching team row so the
--    RLS cutover below does not lock any current supervisor out of their
--    own tasks. standalone_tasks.supervisor_id itself is left untouched
--    (kept as a legacy/primary-supervisor reference; removal is a separate
--    future migration once all code reads from standalone_task_assignees).
-- ─────────────────────────────────────────────────────────────────────────

INSERT INTO public.standalone_task_assignees (tenant_id, task_id, supervisor_id)
SELECT st.tenant_id, st.id, st.supervisor_id
FROM public.standalone_tasks st
WHERE st.supervisor_id IS NOT NULL
ON CONFLICT (task_id, supervisor_id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────
-- 6. standalone_tasks RLS cutover: supervisor access now comes from
--    standalone_task_assignees (the team) instead of the single
--    supervisor_id column. Authoritative versions replace the ones from
--    2026-07-20_multi_tenant_rls.sql.
-- ─────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS supervisor_view_assigned_tasks ON public.standalone_tasks;
CREATE POLICY supervisor_view_assigned_tasks ON public.standalone_tasks
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees sta
      WHERE sta.task_id = standalone_tasks.id AND sta.supervisor_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin')
    )
  );

DROP POLICY IF EXISTS supervisor_update_assigned_tasks ON public.standalone_tasks;
CREATE POLICY supervisor_update_assigned_tasks ON public.standalone_tasks
  FOR UPDATE TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees sta
      WHERE sta.task_id = standalone_tasks.id AND sta.supervisor_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin')
    )
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.standalone_task_assignees sta
      WHERE sta.task_id = standalone_tasks.id AND sta.supervisor_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin')
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 7. Atomic RPCs. Each performs one UPDATE guarded by the expected current
--    state (status = ...) in the same statement Postgres executes under the
--    row's lock, so two team members racing to start/end the same visit (or
--    confirm payment twice) can never both succeed — the loser's UPDATE
--    simply matches zero rows. SECURITY DEFINER bypasses RLS, so every
--    authorization check RLS would normally apply is re-implemented
--    explicitly inside the function (tenant_id + "is this caller on the
--    task's team, or an admin" for both the write and the final read, so a
--    caller who is not entitled to see the task cannot use the RPC as a
--    side channel to read its status either).
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.start_standalone_task_visit(
  p_task_id UUID,
  p_lat NUMERIC DEFAULT NULL,
  p_lng NUMERIC DEFAULT NULL
)
RETURNS TABLE(started BOOLEAN, status TEXT, visit_started_at TIMESTAMPTZ, started_by UUID)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rows INTEGER := 0;
BEGIN
  UPDATE standalone_tasks st
  SET status = 'in_progress',
      visit_started_at = now(),
      visit_started_lat = p_lat,
      visit_started_lng = p_lng,
      started_by = auth.uid()
  WHERE st.id = p_task_id
    AND st.status = 'pending'
    AND st.tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM standalone_task_assignees sta
      WHERE sta.task_id = st.id AND sta.supervisor_id = auth.uid()
    );
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  RETURN QUERY
  SELECT v_rows > 0, st.status, st.visit_started_at, st.started_by
  FROM standalone_tasks st
  WHERE st.id = p_task_id
    AND st.tenant_id = public.current_tenant_id()
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM standalone_task_assignees sta
        WHERE sta.task_id = st.id AND sta.supervisor_id = auth.uid()
      )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_standalone_task_visit(UUID, NUMERIC, NUMERIC) TO authenticated;

CREATE OR REPLACE FUNCTION public.end_standalone_task_visit(
  p_task_id UUID,
  p_lat NUMERIC DEFAULT NULL,
  p_lng NUMERIC DEFAULT NULL
)
RETURNS TABLE(ended BOOLEAN, status TEXT, reason TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rows INTEGER := 0;
BEGIN
  -- The "no pending items" check lives inside the UPDATE's WHERE clause
  -- itself (not a separate SELECT beforehand) so item completion and the
  -- status transition are evaluated as a single atomic statement.
  UPDATE standalone_tasks st
  SET status = 'completed',
      visit_ended_at = now(),
      visit_ended_lat = p_lat,
      visit_ended_lng = p_lng,
      ended_by = auth.uid()
  WHERE st.id = p_task_id
    AND st.status = 'in_progress'
    AND st.tenant_id = public.current_tenant_id()
    AND NOT EXISTS (
      SELECT 1 FROM standalone_task_items sti
      WHERE sti.task_id = st.id AND sti.status <> 'completed'
    )
    AND EXISTS (
      SELECT 1 FROM standalone_task_assignees sta
      WHERE sta.task_id = st.id AND sta.supervisor_id = auth.uid()
    );
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  RETURN QUERY
  SELECT
    v_rows > 0,
    st.status,
    CASE
      WHEN v_rows > 0 THEN NULL
      WHEN st.status <> 'in_progress' THEN 'already_ended'
      WHEN EXISTS (SELECT 1 FROM standalone_task_items sti WHERE sti.task_id = st.id AND sti.status <> 'completed') THEN 'pending_items'
      ELSE 'not_authorized'
    END
  FROM standalone_tasks st
  WHERE st.id = p_task_id
    AND st.tenant_id = public.current_tenant_id()
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM standalone_task_assignees sta
        WHERE sta.task_id = st.id AND sta.supervisor_id = auth.uid()
      )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.end_standalone_task_visit(UUID, NUMERIC, NUMERIC) TO authenticated;

CREATE OR REPLACE FUNCTION public.confirm_standalone_task_payment(
  p_task_id UUID,
  p_payment_method TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(confirmed BOOLEAN, payment_status TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rows INTEGER := 0;
  v_cost NUMERIC;
BEGIN
  IF p_payment_method NOT IN ('cash', 'transfer') THEN
    RAISE EXCEPTION 'invalid payment method: %', p_payment_method;
  END IF;

  UPDATE standalone_tasks st
  SET payment_status = 'paid',
      payment_method = p_payment_method,
      payment_confirmed_at = now(),
      payment_confirmed_by = auth.uid()
  WHERE st.id = p_task_id
    AND st.status = 'completed'
    AND st.payment_status = 'unpaid'
    AND st.tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM standalone_task_assignees sta
      WHERE sta.task_id = st.id AND sta.supervisor_id = auth.uid()
    )
  RETURNING st.cost INTO v_cost;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows > 0 THEN
    INSERT INTO standalone_task_payments (task_id, amount, payment_method, notes, payment_date)
    VALUES (p_task_id, COALESCE(v_cost, 0), p_payment_method, p_notes, CURRENT_DATE);
  END IF;

  RETURN QUERY
  SELECT v_rows > 0, st.payment_status
  FROM standalone_tasks st
  WHERE st.id = p_task_id
    AND st.tenant_id = public.current_tenant_id()
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM standalone_task_assignees sta
        WHERE sta.task_id = st.id AND sta.supervisor_id = auth.uid()
      )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_standalone_task_payment(UUID, TEXT, TEXT) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 8. Realtime: let all team members' devices see start/end/payment/item
--    changes instantly instead of polling. RLS still applies to what each
--    subscriber actually receives.
-- ─────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'standalone_tasks'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.standalone_tasks;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'standalone_task_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.standalone_task_items;
  END IF;
END $$;
