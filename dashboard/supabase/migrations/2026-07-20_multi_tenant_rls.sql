-- Multi-tenant SaaS conversion — Phase 2: RLS rewrite.
--
-- Depends on 2026-07-19_multi_tenant_foundation.sql (tenants table, tenant_id
-- columns, current_tenant_id()) and 2026-07-19b_multi_tenant_default_hotfix.sql.
--
-- Every existing RLS policy that checks public.is_admin() or an ownership/
-- assignment column is rewritten to also require tenant_id = current_tenant_id(),
-- so one company's admin/supervisor/client can no longer see another
-- company's rows. The few policies that were `USING (true)` for any
-- authenticated user (geographic_lines, zones, blocks, contract_types,
-- task_photos) are replaced with real tenant-scoped policies — those were
-- already a data leak even before multi-tenancy and are fixed here too.
--
-- Also: notifications gets its own tenant_id column (broadcast rows have
-- user_id IS NULL, so tenant can't be derived from user_id alone), with an
-- auto-fill trigger so any insert that only sets user_id (including the
-- upayment-webhook/verify-upayment edge functions, not yet updated for
-- multi-tenancy — that's Phase 4) still gets a correct tenant_id for free.

-- ═══════════════════════════════════════════════════════════════════════
-- 1. notifications: add tenant_id + auto-fill trigger
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS tenant_id uuid;

UPDATE public.notifications n
SET tenant_id = u.tenant_id
FROM public.users u
WHERE n.user_id = u.id
  AND n.tenant_id IS NULL;

UPDATE public.notifications
SET tenant_id = 'faf164d1-64f3-4b35-99c7-242118dd76c5'
WHERE tenant_id IS NULL;

ALTER TABLE public.notifications ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.notifications ALTER COLUMN tenant_id SET DEFAULT 'faf164d1-64f3-4b35-99c7-242118dd76c5';

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notifications_tenant_id_fkey') THEN
    ALTER TABLE public.notifications
      ADD CONSTRAINT notifications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON public.notifications(tenant_id);

-- If a caller only supplies user_id, derive tenant_id from that user so
-- inserts that haven't been updated to pass tenant_id explicitly still land
-- in the right tenant instead of silently falling back to Ensdim.
CREATE OR REPLACE FUNCTION public.notifications_autofill_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.tenant_id IS NULL AND NEW.user_id IS NOT NULL THEN
    SELECT tenant_id INTO NEW.tenant_id FROM public.users WHERE id = NEW.user_id;
  END IF;

  IF NEW.tenant_id IS NULL THEN
    NEW.tenant_id := 'faf164d1-64f3-4b35-99c7-242118dd76c5';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifications_autofill_tenant ON public.notifications;
CREATE TRIGGER trg_notifications_autofill_tenant
  BEFORE INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.notifications_autofill_tenant();

-- ═══════════════════════════════════════════════════════════════════════
-- 2. users / user_roles — protect against tenant-hopping, scope admin access
-- ═══════════════════════════════════════════════════════════════════════

-- A user must never be able to change their own tenant_id via "Update own profile".
REVOKE UPDATE (tenant_id) ON public.users FROM authenticated;

DROP POLICY IF EXISTS "Admins manage users" ON public.users;
CREATE POLICY "Admins manage users" ON public.users
  FOR ALL
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Admins manage roles" ON public.user_roles;
CREATE POLICY "Admins manage roles" ON public.user_roles
  FOR ALL
  USING (
    public.is_admin()
    AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = user_roles.user_id AND u.tenant_id = public.current_tenant_id())
  )
  WITH CHECK (
    public.is_admin()
    AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = user_roles.user_id AND u.tenant_id = public.current_tenant_id())
  );

-- ═══════════════════════════════════════════════════════════════════════
-- 3. geographic_lines / zones / blocks / contract_types
--    (previously "Authenticated read X" USING (true) — any authenticated
--    user, any tenant, could read all of these; that's fixed here)
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Admins full access lines" ON public.geographic_lines;
CREATE POLICY "Admins full access lines" ON public.geographic_lines
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());
DROP POLICY IF EXISTS "Authenticated read lines" ON public.geographic_lines;
CREATE POLICY "Authenticated read lines" ON public.geographic_lines
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Admins full access zones" ON public.zones;
CREATE POLICY "Admins full access zones" ON public.zones
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());
DROP POLICY IF EXISTS "Authenticated read zones" ON public.zones;
CREATE POLICY "Authenticated read zones" ON public.zones
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Admins full access blocks" ON public.blocks;
CREATE POLICY "Admins full access blocks" ON public.blocks
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());
DROP POLICY IF EXISTS "Authenticated read blocks" ON public.blocks;
CREATE POLICY "Authenticated read blocks" ON public.blocks
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Admins full access contract_types" ON public.contract_types;
CREATE POLICY "Admins full access contract_types" ON public.contract_types
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());
DROP POLICY IF EXISTS "Authenticated read contract_types" ON public.contract_types;
CREATE POLICY "Authenticated read contract_types" ON public.contract_types
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

-- ═══════════════════════════════════════════════════════════════════════
-- 4. contracts
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Admins full access contracts" ON public.contracts;
CREATE POLICY "Admins full access contracts" ON public.contracts
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Clients read own contracts" ON public.contracts;
CREATE POLICY "Clients read own contracts" ON public.contracts
  FOR SELECT USING (user_id = auth.uid() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Clients update own guard info" ON public.contracts;
CREATE POLICY "Clients update own guard info" ON public.contracts
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND tenant_id = public.current_tenant_id())
  WITH CHECK (user_id = auth.uid() AND tenant_id = public.current_tenant_id());

-- ═══════════════════════════════════════════════════════════════════════
-- 5. visits
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "admin_all_visits" ON public.visits;
CREATE POLICY "admin_all_visits" ON public.visits FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND visits.tenant_id = public.current_tenant_id()
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND visits.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "supervisor_read_visits" ON public.visits;
CREATE POLICY "supervisor_read_visits" ON public.visits FOR SELECT TO authenticated USING (
  visits.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    WHERE u.id = auth.uid() AND c.id = visits.contract_id
  )
);

DROP POLICY IF EXISTS "supervisor_insert_visits" ON public.visits;
CREATE POLICY "supervisor_insert_visits" ON public.visits FOR INSERT TO authenticated WITH CHECK (
  visits.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    WHERE u.id = auth.uid() AND c.id = visits.contract_id
  )
);

DROP POLICY IF EXISTS "supervisor_update_visits" ON public.visits;
CREATE POLICY "supervisor_update_visits" ON public.visits FOR UPDATE TO authenticated USING (
  visits.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    WHERE u.id = auth.uid() AND c.id = visits.contract_id
  )
);

-- ═══════════════════════════════════════════════════════════════════════
-- 6. contract_tasks
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "admin_all_contract_tasks" ON public.contract_tasks;
CREATE POLICY "admin_all_contract_tasks" ON public.contract_tasks FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND contract_tasks.tenant_id = public.current_tenant_id()
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND contract_tasks.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "supervisor_read_contract_tasks" ON public.contract_tasks;
CREATE POLICY "supervisor_read_contract_tasks" ON public.contract_tasks FOR SELECT TO authenticated USING (
  contract_tasks.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    WHERE u.id = auth.uid() AND c.id = contract_tasks.contract_id
  )
);

DROP POLICY IF EXISTS "supervisor_update_contract_tasks" ON public.contract_tasks;
CREATE POLICY "supervisor_update_contract_tasks" ON public.contract_tasks FOR UPDATE TO authenticated USING (
  contract_tasks.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    WHERE u.id = auth.uid() AND c.id = contract_tasks.contract_id
  )
);

-- ═══════════════════════════════════════════════════════════════════════
-- 7. task_executions
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Admins full access executions" ON public.task_executions;
CREATE POLICY "Admins full access executions" ON public.task_executions
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "supervisor_insert_task_executions" ON public.task_executions;
CREATE POLICY "supervisor_insert_task_executions" ON public.task_executions FOR INSERT TO authenticated WITH CHECK (
  supervisor_id = auth.uid() AND tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "supervisor_read_task_executions" ON public.task_executions;
CREATE POLICY "supervisor_read_task_executions" ON public.task_executions FOR SELECT TO authenticated USING (
  supervisor_id = auth.uid() AND tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "client_read_task_executions" ON public.task_executions;
CREATE POLICY "client_read_task_executions" ON public.task_executions FOR SELECT TO authenticated USING (
  task_executions.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.contract_tasks ct
    JOIN public.contracts c ON c.id = ct.contract_id
    WHERE ct.id = task_executions.task_id AND c.user_id = auth.uid()
  )
);

-- ═══════════════════════════════════════════════════════════════════════
-- 8. task_photos
--    Previously "Authenticated read photos" was USING (true) — ANY
--    authenticated user, any tenant, any role, could read ANY task photo.
--    Replaced with real admin/supervisor/client-scoped policies.
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Admins full access photos" ON public.task_photos;
CREATE POLICY "Admins full access photos" ON public.task_photos
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Authenticated read photos" ON public.task_photos;

DROP POLICY IF EXISTS "supervisor_read_task_photos" ON public.task_photos;
CREATE POLICY "supervisor_read_task_photos" ON public.task_photos FOR SELECT TO authenticated USING (
  task_photos.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.task_executions te
    JOIN public.contract_tasks ct ON ct.id = te.task_id
    JOIN public.contracts c ON c.id = ct.contract_id
    JOIN public.zones z ON z.line_id = (SELECT u.assigned_line_id FROM public.users u WHERE u.id = auth.uid())
    WHERE te.id = task_photos.execution_id AND c.zone_id = z.id
  )
);

DROP POLICY IF EXISTS "client_read_task_photos" ON public.task_photos;
CREATE POLICY "client_read_task_photos" ON public.task_photos FOR SELECT TO authenticated USING (
  task_photos.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.task_executions te
    JOIN public.contract_tasks ct ON ct.id = te.task_id
    JOIN public.contracts c ON c.id = ct.contract_id
    WHERE te.id = task_photos.execution_id AND c.user_id = auth.uid()
  )
);

-- ═══════════════════════════════════════════════════════════════════════
-- 9. visit_photos
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "admin_all_visit_photos" ON public.visit_photos;
CREATE POLICY "admin_all_visit_photos" ON public.visit_photos FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND visit_photos.tenant_id = public.current_tenant_id()
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND visit_photos.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "supervisor_manage_visit_photos" ON public.visit_photos;
CREATE POLICY "supervisor_manage_visit_photos" ON public.visit_photos FOR ALL TO authenticated USING (
  visit_photos.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    JOIN public.visits v ON v.contract_id = c.id
    WHERE u.id = auth.uid() AND v.id = visit_photos.visit_id
  )
);

DROP POLICY IF EXISTS "client_read_visit_photos" ON public.visit_photos;
CREATE POLICY "client_read_visit_photos" ON public.visit_photos FOR SELECT TO authenticated USING (
  visit_photos.tenant_id = public.current_tenant_id()
  AND EXISTS (
    SELECT 1 FROM public.visits v
    JOIN public.contracts c ON c.id = v.contract_id
    WHERE v.id = visit_photos.visit_id AND c.user_id = auth.uid()
  )
);

-- ═══════════════════════════════════════════════════════════════════════
-- 10. client_comments (+ can_current_user_comment_contract RPC)
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.can_current_user_comment_contract(p_contract_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR p_contract_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.contracts c
    WHERE c.id = p_contract_id
      AND c.user_id = auth.uid()
      AND c.tenant_id = public.current_tenant_id()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_current_user_comment_contract(uuid) TO authenticated;

DROP POLICY IF EXISTS "Admins full access comments" ON public.client_comments;
CREATE POLICY "Admins full access comments" ON public.client_comments
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Clients create comments" ON public.client_comments;
CREATE POLICY "Clients create comments" ON public.client_comments
  FOR INSERT WITH CHECK (public.can_current_user_comment_contract(client_comments.contract_id));

DROP POLICY IF EXISTS "Clients read own comments" ON public.client_comments;
CREATE POLICY "Clients read own comments" ON public.client_comments
  FOR SELECT USING (public.can_current_user_comment_contract(client_comments.contract_id));

DROP POLICY IF EXISTS "Supervisors read assigned visit comments" ON public.client_comments;
CREATE POLICY "Supervisors read assigned visit comments" ON public.client_comments
  FOR SELECT USING (
    client_comments.tenant_id = public.current_tenant_id()
    AND client_comments.visit_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.visits        v
      JOIN public.contracts     c  ON c.id  = v.contract_id
      LEFT JOIN public.zones    zd ON zd.id = c.zone_id
      LEFT JOIN public.blocks   b  ON b.id  = c.block_id
      LEFT JOIN public.zones    zb ON zb.id = b.zone_id
      JOIN public.users         u  ON u.assigned_line_id = COALESCE(zd.line_id, zb.line_id)
      WHERE v.id   = client_comments.visit_id
        AND u.id   = auth.uid()
        AND COALESCE(zd.line_id, zb.line_id) IS NOT NULL
    )
  );

-- ═══════════════════════════════════════════════════════════════════════
-- 11. supervisor_notes
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Supervisors and admins manage supervisor notes" ON public.supervisor_notes;
CREATE POLICY "Supervisors and admins manage supervisor notes" ON public.supervisor_notes
  FOR ALL
  USING (
    supervisor_notes.tenant_id = public.current_tenant_id()
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1
        FROM public.visits v
        JOIN public.contracts c ON c.id = v.contract_id
        JOIN public.zones z ON z.id = c.zone_id
        JOIN public.users u ON u.assigned_line_id = z.line_id
        WHERE v.id = supervisor_notes.visit_id AND u.id = auth.uid()
      )
    )
  )
  WITH CHECK (
    supervisor_notes.tenant_id = public.current_tenant_id()
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1
        FROM public.visits v
        JOIN public.contracts c ON c.id = v.contract_id
        JOIN public.zones z ON z.id = c.zone_id
        JOIN public.users u ON u.assigned_line_id = z.line_id
        WHERE v.id = supervisor_notes.visit_id AND u.id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "Clients read visible supervisor notes" ON public.supervisor_notes;
CREATE POLICY "Clients read visible supervisor notes" ON public.supervisor_notes
  FOR SELECT USING (
    supervisor_notes.tenant_id = public.current_tenant_id()
    AND visibility = 'all'
    AND EXISTS (
      SELECT 1 FROM public.contracts c
      WHERE c.id = supervisor_notes.contract_id AND c.user_id = auth.uid()
    )
  );

-- ═══════════════════════════════════════════════════════════════════════
-- 12. contract_status_requests (+ create/review RPCs)
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Supervisors can create contract status requests" ON public.contract_status_requests;
CREATE POLICY "Supervisors can create contract status requests" ON public.contract_status_requests
  FOR INSERT WITH CHECK (supervisor_id = auth.uid() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Supervisors can view their contract status requests" ON public.contract_status_requests;
CREATE POLICY "Supervisors can view their contract status requests" ON public.contract_status_requests
  FOR SELECT USING (
    tenant_id = public.current_tenant_id()
    AND (supervisor_id = auth.uid() OR public.is_admin())
  );

DROP POLICY IF EXISTS "Admins manage contract status requests" ON public.contract_status_requests;
CREATE POLICY "Admins manage contract status requests" ON public.contract_status_requests
  FOR ALL
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

CREATE OR REPLACE FUNCTION public.create_contract_status_request(
  p_contract_id uuid,
  p_requested_status text
)
RETURNS public.contract_status_requests
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_supervisor_name text;
  v_contract public.contracts_view%rowtype;
  v_tenant_id uuid;
  v_request public.contract_status_requests;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_requested_status NOT IN ('active', 'pending', 'expired', 'cancelled', 'terminated') THEN
    RAISE EXCEPTION 'Invalid requested status';
  END IF;

  SELECT * INTO v_contract FROM public.contracts_view WHERE id = p_contract_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Contract not found';
  END IF;

  SELECT tenant_id INTO v_tenant_id FROM public.contracts WHERE id = p_contract_id;

  IF p_requested_status = v_contract.status THEN
    RAISE EXCEPTION 'Requested status matches current status';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.contract_status_requests r
    WHERE r.contract_id = p_contract_id AND r.supervisor_id = v_user_id AND r.status = 'pending'
  ) THEN
    RAISE EXCEPTION 'A pending request already exists for this contract';
  END IF;

  SELECT coalesce(full_name, email, v_user_id::text) INTO v_supervisor_name
  FROM public.users WHERE id = v_user_id;

  INSERT INTO public.contract_status_requests (contract_id, supervisor_id, current_status, requested_status, tenant_id)
  VALUES (p_contract_id, v_user_id, v_contract.status, p_requested_status, v_tenant_id)
  RETURNING * INTO v_request;

  INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
  SELECT
    u.id,
    format('طلب تغيير حالة للعقد %s', coalesce(v_contract.code::text, p_contract_id::text)),
    format('%s طلب تغيير حالة العقد %s من %s إلى %s',
      coalesce(v_supervisor_name, v_user_id::text),
      coalesce(v_contract.code::text, p_contract_id::text),
      CASE v_request.current_status
        WHEN 'active' THEN 'نشط' WHEN 'pending' THEN 'قيد الانتظار' WHEN 'expired' THEN 'منتهي'
        WHEN 'terminated' THEN 'ملغي' WHEN 'cancelled' THEN 'ملغي' ELSE v_request.current_status END,
      CASE v_request.requested_status
        WHEN 'active' THEN 'نشط' WHEN 'pending' THEN 'قيد الانتظار' WHEN 'expired' THEN 'منتهي'
        WHEN 'terminated' THEN 'ملغي' WHEN 'cancelled' THEN 'ملغي' ELSE v_request.requested_status END
    ),
    json_build_object('contract_id', v_request.contract_id, 'request_id', v_request.id)::jsonb,
    v_tenant_id
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  JOIN public.users u ON u.id = ur.user_id
  WHERE r.name = 'admin' AND u.tenant_id = v_tenant_id;

  RETURN v_request;
END;
$$;

CREATE OR REPLACE FUNCTION public.review_contract_status_request(
  p_request_id uuid,
  p_decision text,
  p_admin_notes text DEFAULT NULL
)
RETURNS public.contract_status_requests
LANGUAGE plpgsql
AS $$
DECLARE
  v_request public.contract_status_requests;
  v_contract_code text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admins only';
  END IF;

  SELECT * INTO v_request FROM public.contract_status_requests WHERE id = p_request_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  IF v_request.tenant_id <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  IF v_request.status <> 'pending' THEN
    RAISE EXCEPTION 'Request has already been reviewed';
  END IF;

  IF p_decision NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;

  UPDATE public.contract_status_requests
  SET status = p_decision, admin_notes = coalesce(p_admin_notes, admin_notes), reviewed_by = auth.uid(), reviewed_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  IF p_decision = 'approved' THEN
    UPDATE public.contracts SET status = v_request.requested_status WHERE id = v_request.contract_id;
  END IF;

  SELECT code INTO v_contract_code FROM public.contracts WHERE id = v_request.contract_id;

  INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
  VALUES (
    v_request.supervisor_id,
    format('قرار بشأن طلب تغيير حالة العقد %s', coalesce(v_contract_code, v_request.contract_id::text)),
    format('تم %s طلبك لتغيير حالة العقد %s. ملاحظات: %s',
      CASE p_decision WHEN 'approved' THEN 'قبول' WHEN 'rejected' THEN 'رفض' ELSE p_decision END,
      coalesce(v_contract_code, v_request.contract_id::text),
      coalesce(p_admin_notes, '')
    ),
    json_build_object('request_id', v_request.id, 'contract_id', v_request.contract_id, 'decision', p_decision)::jsonb,
    v_request.tenant_id
  );

  RETURN v_request;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_contract_status_request(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.review_contract_status_request(uuid, text, text) TO authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════
-- 13. standalone_tasks / standalone_task_payments
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "admin_all_standalone_tasks" ON public.standalone_tasks;
CREATE POLICY "admin_all_standalone_tasks" ON public.standalone_tasks FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND standalone_tasks.tenant_id = public.current_tenant_id()
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND standalone_tasks.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "supervisor_view_assigned_tasks" ON public.standalone_tasks;
CREATE POLICY "supervisor_view_assigned_tasks" ON public.standalone_tasks FOR SELECT TO authenticated USING (
  supervisor_id = auth.uid()
  AND standalone_tasks.tenant_id = public.current_tenant_id()
  AND EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin'))
);

DROP POLICY IF EXISTS "supervisor_update_assigned_tasks" ON public.standalone_tasks;
CREATE POLICY "supervisor_update_assigned_tasks" ON public.standalone_tasks FOR UPDATE TO authenticated USING (
  supervisor_id = auth.uid()
  AND standalone_tasks.tenant_id = public.current_tenant_id()
  AND EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin'))
) WITH CHECK (
  supervisor_id = auth.uid()
  AND standalone_tasks.tenant_id = public.current_tenant_id()
  AND EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name IN ('supervisor', 'admin'))
);

DROP POLICY IF EXISTS "Clients read own standalone tasks" ON public.standalone_tasks;
CREATE POLICY "Clients read own standalone tasks" ON public.standalone_tasks FOR SELECT TO authenticated USING (
  standalone_tasks.tenant_id = public.current_tenant_id()
  AND (
    standalone_tasks.client_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.contracts c
      WHERE c.id = public.standalone_tasks.contract_id AND c.user_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "Admins manage standalone task payments" ON public.standalone_task_payments;
CREATE POLICY "Admins manage standalone task payments" ON public.standalone_task_payments
  FOR ALL TO authenticated
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Client confirm standalone gateway payment" ON public.standalone_task_payments;
CREATE POLICY "Client confirm standalone gateway payment" ON public.standalone_task_payments
  FOR UPDATE TO authenticated
  USING (
    gateway_status = 'pending'
    AND standalone_task_payments.tenant_id = public.current_tenant_id()
    AND EXISTS (SELECT 1 FROM public.standalone_tasks st WHERE st.id = task_id AND st.client_id = auth.uid())
  )
  WITH CHECK (gateway_status = 'paid');

-- ═══════════════════════════════════════════════════════════════════════
-- 14. invoices / contract_payments
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Admins full access invoices" ON public.invoices;
CREATE POLICY "Admins full access invoices" ON public.invoices
  FOR ALL USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Clients read own invoices" ON public.invoices;
CREATE POLICY "Clients read own invoices" ON public.invoices FOR SELECT USING (
  invoices.tenant_id = public.current_tenant_id()
  AND EXISTS (SELECT 1 FROM public.contracts ct WHERE ct.id = invoices.contract_id AND ct.user_id = auth.uid())
);

DROP POLICY IF EXISTS "Admins full access contract_payments" ON contract_payments;
CREATE POLICY "Admins full access contract_payments" ON contract_payments FOR ALL TO authenticated
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Clients can view own contract payments" ON contract_payments;
CREATE POLICY "Clients can view own contract payments" ON contract_payments FOR SELECT TO authenticated USING (
  contract_payments.tenant_id = public.current_tenant_id()
  AND EXISTS (SELECT 1 FROM contracts c WHERE c.id = contract_payments.contract_id AND c.user_id = auth.uid())
);

DROP POLICY IF EXISTS "Client confirm gateway payment" ON public.contract_payments;
CREATE POLICY "Client confirm gateway payment" ON public.contract_payments FOR UPDATE TO authenticated
  USING (
    gateway_status = 'pending'
    AND contract_payments.tenant_id = public.current_tenant_id()
    AND EXISTS (SELECT 1 FROM public.contracts c WHERE c.id = contract_id AND c.user_id = auth.uid())
  )
  WITH CHECK (gateway_status = 'paid');

-- ═══════════════════════════════════════════════════════════════════════
-- 15. Internal admin-only operational tables
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "admin_all_company_phones" ON public.company_phones;
CREATE POLICY "admin_all_company_phones" ON public.company_phones FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND company_phones.tenant_id = public.current_tenant_id()
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND company_phones.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "admin_all_vehicles" ON public.vehicles;
CREATE POLICY "admin_all_vehicles" ON public.vehicles FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND vehicles.tenant_id = public.current_tenant_id()
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND vehicles.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "admin_all_vehicle_expenses" ON public.vehicle_expenses;
CREATE POLICY "admin_all_vehicle_expenses" ON public.vehicle_expenses FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND vehicle_expenses.tenant_id = public.current_tenant_id()
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND vehicle_expenses.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "admin_all_workers" ON public.workers;
CREATE POLICY "admin_all_workers" ON public.workers FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND workers.tenant_id = public.current_tenant_id()
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
  AND workers.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "Admins manage company expenses" ON company_expenses;
CREATE POLICY "Admins manage company expenses" ON company_expenses FOR ALL TO authenticated
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Admins manage expense sections" ON expense_sections;
CREATE POLICY "Admins manage expense sections" ON expense_sections FOR ALL TO authenticated
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS "Admins manage expense line items" ON expense_line_items;
CREATE POLICY "Admins manage expense line items" ON expense_line_items FOR ALL TO authenticated
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

-- ═══════════════════════════════════════════════════════════════════════
-- 16. contact_requests (public/anon lead form)
-- ═══════════════════════════════════════════════════════════════════════
-- Anon has no auth.uid(), so tenant_id can't be derived from a session here.
-- The column defaults to the Ensdim tenant (hotfix migration), so today's
-- single contact form keeps working unchanged. A future tenant's own
-- contact form/site must pass its own tenant_id explicitly in the insert —
-- flagging this for whoever wires that up, since it's outside this repo's
-- SQL. The WITH CHECK below only guards against garbage/inactive tenant_id.

DROP POLICY IF EXISTS "Public can create contact requests" ON public.contact_requests;
CREATE POLICY "Public can create contact requests" ON public.contact_requests
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.tenants t WHERE t.id = contact_requests.tenant_id AND t.status <> 'suspended')
  );

DROP POLICY IF EXISTS "Admins manage contact requests" ON public.contact_requests;
CREATE POLICY "Admins manage contact requests" ON public.contact_requests
  FOR ALL
  USING (public.is_admin() AND tenant_id = public.current_tenant_id())
  WITH CHECK (public.is_admin() AND tenant_id = public.current_tenant_id());

-- ═══════════════════════════════════════════════════════════════════════
-- 17. notifications RLS (SELECT/INSERT/UPDATE)
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Authenticated read notifications" ON public.notifications;
CREATE POLICY "Authenticated read notifications" ON public.notifications
  FOR SELECT USING (
    user_id = auth.uid()
    OR (user_id IS NULL AND public.is_admin() AND tenant_id = public.current_tenant_id())
  );

DROP POLICY IF EXISTS "Authenticated insert notifications" ON public.notifications;
CREATE POLICY "Authenticated insert notifications" ON public.notifications
  FOR INSERT WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND (user_id IS NULL OR user_id = auth.uid() OR public.is_admin())
  );

DROP POLICY IF EXISTS "Authenticated update notifications" ON public.notifications;
CREATE POLICY "Authenticated update notifications" ON public.notifications
  FOR UPDATE
  USING (user_id = auth.uid() OR (public.is_admin() AND tenant_id = public.current_tenant_id()))
  WITH CHECK (user_id = auth.uid() OR (public.is_admin() AND tenant_id = public.current_tenant_id()));

-- ═══════════════════════════════════════════════════════════════════════
-- 18. Views — recreated with an explicit tenant filter.
--    Views in this project are owned by the migration role (which owns the
--    underlying tables), so by default they run with the OWNER's
--    privileges and bypass the base tables' RLS entirely for anyone with
--    SELECT on the view. Relying on contracts/users/invoices RLS alone
--    would NOT protect contracts_view/users_view/invoices_view — the
--    tenant filter has to be explicit in the view definition itself.
-- ═══════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.users_view CASCADE;
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
WHERE u.deleted_at IS NULL
  AND u.tenant_id = public.current_tenant_id();

GRANT SELECT ON public.users_view TO authenticated;

DROP VIEW IF EXISTS public.contracts_view CASCADE;
CREATE VIEW public.contracts_view AS
SELECT
  c.id,
  c.user_id,
  c.block_id,
  c.code,
  c.contract_type_id,
  c.status,
  c.duration_months,
  c.address_details,
  c.notes,
  c.palm_info,
  c.block_number,
  c.street,
  c.avenue,
  c.house,
  c.kuwait_finder_url,
  c.contract_user_name,
  c.contract_user_phone,
  c.start_date,
  c.first_visit_date,
  c.end_date,
  c.total_value,
  c.terms,
  c.contract_image_url,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  COALESCE(c.zone_id, b.zone_id) AS zone_id,
  z.line_id,
  u.full_name AS client_name,
  u.email AS client_email,
  u.phone AS client_phone
FROM public.contracts c
LEFT JOIN public.blocks b ON b.id = c.block_id
LEFT JOIN public.zones z ON z.id = COALESCE(c.zone_id, b.zone_id)
LEFT JOIN public.users u ON u.id = c.user_id
WHERE c.deleted_at IS NULL
  AND c.tenant_id = public.current_tenant_id();

GRANT SELECT ON public.contracts_view TO authenticated;

DROP VIEW IF EXISTS public.invoices_view CASCADE;
CREATE VIEW public.invoices_view AS
SELECT i.*
FROM public.invoices i
WHERE i.deleted_at IS NULL
  AND i.tenant_id = public.current_tenant_id();

GRANT SELECT ON public.invoices_view TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════
-- 19. update_contract_guard_info — drop the dead legacy `clients` table path
--    (that table was removed months ago); ownership check already implies
--    same tenant, so no extra tenant predicate is needed here.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_contract_guard_info(
  p_contract_id uuid,
  p_guard_name text,
  p_guard_phone text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rows_updated integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING errcode = '28000';
  END IF;

  UPDATE public.contracts
  SET
    contract_user_name = nullif(trim(p_guard_name), ''),
    contract_user_phone = nullif(trim(p_guard_phone), '')
  WHERE id = p_contract_id
    AND user_id = auth.uid();

  GET DIAGNOSTICS rows_updated = ROW_COUNT;

  IF rows_updated = 0 THEN
    RAISE EXCEPTION 'contract_not_found_or_not_owned' USING errcode = '42501';
  END IF;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_contract_guard_info(uuid, text, text) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════
-- 20. "Notify all admins" trigger functions — scope broadcast to the
--     same tenant as the row that triggered them.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_supervisor_note_to_admins()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author text;
  v_contract_code text;
  v_visit_title text;
  v_visit_notes text;
  v_visit_date date;
  v_visit_label text;
  v_contract_user uuid;
BEGIN
  IF tg_op <> 'INSERT' THEN
    RETURN new;
  END IF;

  SELECT coalesce(nullif(trim(u.full_name), ''), u.email, 'المشرف') INTO v_author
  FROM public.users u WHERE u.id = new.created_by;

  SELECT c.code, c.user_id INTO v_contract_code, v_contract_user
  FROM public.contracts c WHERE c.id = new.contract_id;

  SELECT v.title, v.notes, v.visit_date INTO v_visit_title, v_visit_notes, v_visit_date
  FROM public.visits v WHERE v.id = new.visit_id;

  v_visit_label := coalesce(
    nullif(trim(v_visit_title), ''),
    nullif(trim(v_visit_notes), ''),
    CASE WHEN v_visit_date IS NOT NULL THEN to_char(v_visit_date, 'YYYY-MM-DD') END,
    'الزيارة'
  );

  INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
  SELECT
    u.id,
    'تمت إضافة ملاحظة من المشرف',
    'أضاف ' || coalesce(v_author, 'المشرف') || ' ملاحظة على ' || v_visit_label ||
      CASE WHEN v_contract_code IS NOT NULL THEN ' في العقد ' || v_contract_code ELSE '' END || '.',
    jsonb_build_object(
      'type', 'supervisor_note', 'contract_id', new.contract_id, 'visit_id', new.visit_id,
      'note_id', new.id, 'author_name', coalesce(v_author, 'المشرف'), 'visibility', new.visibility
    ),
    new.tenant_id
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  JOIN public.users u ON u.id = ur.user_id
  WHERE r.name = 'admin' AND u.tenant_id = new.tenant_id;

  IF new.visibility = 'all' AND v_contract_user IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
    VALUES (
      v_contract_user,
      'تمت إضافة ملاحظة على عقدك',
      'أضاف ' || coalesce(v_author, 'المشرف') || ' ملاحظة على ' || v_visit_label || '.',
      jsonb_build_object(
        'type', 'supervisor_note', 'contract_id', new.contract_id, 'visit_id', new.visit_id,
        'note_id', new.id, 'author_name', coalesce(v_author, 'المشرف'), 'visibility', new.visibility
      ),
      new.tenant_id
    );
  END IF;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_client_comment_to_admins()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author text;
  v_contract_code text;
  v_visit_title text;
  v_visit_notes text;
  v_visit_date date;
  v_visit_label text;
BEGIN
  IF tg_op <> 'INSERT' THEN
    RETURN new;
  END IF;

  v_author := coalesce(nullif(trim(new.author_name), ''), 'العميل');

  SELECT c.code INTO v_contract_code FROM public.contracts c WHERE c.id = new.contract_id;

  SELECT v.title, v.notes, v.visit_date INTO v_visit_title, v_visit_notes, v_visit_date
  FROM public.visits v WHERE v.id = new.visit_id;

  v_visit_label := coalesce(
    nullif(trim(v_visit_title), ''),
    nullif(trim(v_visit_notes), ''),
    CASE WHEN v_visit_date IS NOT NULL THEN to_char(v_visit_date, 'YYYY-MM-DD') END,
    'الزيارة'
  );

  INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
  SELECT
    u.id,
    'تعليق عميل جديد',
    v_author || ' أضاف تعليقًا على ' || v_visit_label ||
      CASE WHEN v_contract_code IS NOT NULL THEN ' (عقد ' || v_contract_code || ')' ELSE '' END,
    jsonb_build_object('type', 'client_comment', 'contract_id', new.contract_id, 'visit_id', new.visit_id, 'comment_id', new.id, 'author_name', v_author),
    new.tenant_id
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  JOIN public.users u ON u.id = ur.user_id
  WHERE r.name = 'admin' AND u.tenant_id = new.tenant_id;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_visit_completed_to_admins()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contract_code  text;
  v_supervisor_name text;
  v_completed_at   timestamptz;
  v_summary        text;
  v_body           text;
BEGIN
  IF tg_op <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF NEW.status <> 'completed' OR OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;

  BEGIN
    SELECT c.code INTO v_contract_code FROM public.contracts c WHERE c.id = NEW.contract_id;
  EXCEPTION WHEN OTHERS THEN
    v_contract_code := NULL;
  END;

  BEGIN
    SELECT coalesce(u.full_name, u.email, 'المشرف') INTO v_supervisor_name
    FROM public.task_executions te
    LEFT JOIN public.users u ON u.id = te.supervisor_id
    WHERE te.visit_id = NEW.id
    ORDER BY te.created_at DESC LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v_supervisor_name := NULL;
  END;

  v_completed_at := coalesce(NEW.completed_at, now());
  v_summary := nullif(trim(coalesce(NEW.summary, '')), '');

  v_body :=
    coalesce(v_supervisor_name, 'المشرف') || ' أنهى زيارة العقد ' || coalesce(v_contract_code, 'غير معروف') ||
    coalesce(' بتاريخ ' || to_char(NEW.visit_date, 'YYYY-MM-DD'), '') ||
    CASE WHEN v_summary IS NOT NULL THEN ' - ملخص: ' || left(v_summary, 140) ELSE '' END;

  BEGIN
    INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
    SELECT
      u.id,
      'تم إنهاء زيارة',
      v_body,
      jsonb_build_object(
        'type', 'visit_completed', 'contract_id', NEW.contract_id, 'visit_id', NEW.id,
        'visit_date', NEW.visit_date, 'completed_at', v_completed_at, 'summary', coalesce(NEW.summary, ''),
        'supervisor_name', coalesce(v_supervisor_name, 'المشرف'), 'contract_code', coalesce(v_contract_code, '')
      ),
      NEW.tenant_id
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    JOIN public.users u ON u.id = ur.user_id
    WHERE r.name = 'admin' AND u.tenant_id = NEW.tenant_id;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_contact_request_to_admins()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
  v_phone text;
BEGIN
  IF tg_op <> 'INSERT' THEN
    RETURN new;
  END IF;

  v_name := coalesce(nullif(trim(new.full_name), ''), 'عميل محتمل');
  v_phone := coalesce(nullif(trim(new.phone), ''), '');

  INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
  SELECT
    u.id,
    'طلب عميل جديد',
    v_name || ' سجل طلب تواصل جديد' || CASE WHEN v_phone <> '' THEN ' — ' || v_phone ELSE '' END,
    jsonb_build_object('type', 'contact_request', 'request_id', new.id, 'full_name', v_name, 'phone', v_phone),
    new.tenant_id
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  JOIN public.users u ON u.id = ur.user_id
  WHERE r.name = 'admin' AND u.tenant_id = new.tenant_id;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_contract_expiry_on_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text;
  v_title text;
  v_body text;
  v_days_left integer;
  v_exists boolean;
BEGIN
  IF tg_op = 'INSERT' OR (tg_op = 'UPDATE' AND (old.end_date IS DISTINCT FROM new.end_date)) THEN
    IF new.end_date IS NULL THEN
      RETURN new;
    END IF;

    v_days_left := (new.end_date::date - current_date);

    IF v_days_left <= 0 THEN
      v_type := 'contract_expired';
      v_title := format('العقد %s منتهي', coalesce(new.code, new.id::text));
      v_body := format('تاريخ انتهاء العقد %s هو %s، وقد انتهى الآن.', coalesce(new.code, new.id::text), to_char(new.end_date, 'YYYY-MM-DD'));
    ELSIF v_days_left = 15 THEN
      v_type := 'contract_expiring_15';
      v_title := format('العقد %s ينتهي خلال 15 يومًا', coalesce(new.code, new.id::text));
      v_body := format('متبقي 15 يومًا على انتهاء العقد %s. تاريخ الانتهاء: %s.', coalesce(new.code, new.id::text), to_char(new.end_date, 'YYYY-MM-DD'));
    ELSIF v_days_left = 30 THEN
      v_type := 'contract_expiring_30';
      v_title := format('العقد %s ينتهي خلال 30 يومًا', coalesce(new.code, new.id::text));
      v_body := format('متبقي 30 يومًا على انتهاء العقد %s. تاريخ الانتهاء: %s.', coalesce(new.code, new.id::text), to_char(new.end_date, 'YYYY-MM-DD'));
    ELSE
      RETURN new;
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE coalesce(n.meta->>'type','') = v_type
        AND coalesce(n.meta->>'contract_id','') = new.id::text
        AND coalesce(n.meta->>'end_date','') = to_char(new.end_date::date, 'YYYY-MM-DD')
    ) INTO v_exists;

    IF NOT v_exists THEN
      INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
      SELECT
        u.id, v_title, v_body,
        jsonb_build_object('type', v_type, 'contract_id', new.id, 'contract_code', new.code, 'end_date', new.end_date::date, 'days_left', v_days_left),
        new.tenant_id
      FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      JOIN public.users u ON u.id = ur.user_id
      WHERE r.name = 'admin' AND u.tenant_id = new.tenant_id;

      IF new.user_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
        VALUES (
          new.user_id, v_title, v_body,
          jsonb_build_object('type', v_type, 'contract_id', new.id, 'contract_code', new.code, 'end_date', new.end_date, 'days_left', v_days_left),
          new.tenant_id
        );
      END IF;

      IF v_days_left <= 0 AND coalesce(new.status, '') <> 'expired' THEN
        UPDATE public.contracts SET status = 'expired' WHERE id = new.id;
      END IF;
    END IF;
  END IF;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_contract_expiry_notifications()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_contract record;
  v_type text;
  v_title text;
  v_body text;
  v_days_left integer;
  v_exists boolean;
  v_inserted integer := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admins only';
  END IF;

  FOR v_contract IN
    SELECT id, code, end_date, user_id, tenant_id
    FROM public.contracts
    WHERE end_date IS NOT NULL
      AND (end_date::date) <= current_date + 30
      AND tenant_id = public.current_tenant_id()
  LOOP
    v_days_left := (v_contract.end_date::date - current_date);

    IF v_days_left <= 0 THEN
      v_type := 'contract_expired';
      v_title := format('العقد %s منتهي', coalesce(v_contract.code, v_contract.id::text));
      v_body := format('تاريخ انتهاء العقد %s هو %s، وقد انتهى الآن.', coalesce(v_contract.code, v_contract.id::text), to_char(v_contract.end_date, 'YYYY-MM-DD'));
    ELSIF v_days_left = 15 THEN
      v_type := 'contract_expiring_15';
      v_title := format('العقد %s ينتهي خلال 15 يومًا', coalesce(v_contract.code, v_contract.id::text));
      v_body := format('متبقي 15 يومًا على انتهاء العقد %s. تاريخ الانتهاء: %s.', coalesce(v_contract.code, v_contract.id::text), to_char(v_contract.end_date, 'YYYY-MM-DD'));
    ELSIF v_days_left = 30 THEN
      v_type := 'contract_expiring_30';
      v_title := format('العقد %s ينتهي خلال 30 يومًا', coalesce(v_contract.code, v_contract.id::text));
      v_body := format('متبقي 30 يومًا على انتهاء العقد %s. تاريخ الانتهاء: %s.', coalesce(v_contract.code, v_contract.id::text), to_char(v_contract.end_date, 'YYYY-MM-DD'));
    ELSE
      CONTINUE;
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE coalesce(n.meta->>'type', '') = v_type
        AND coalesce(n.meta->>'contract_id', '') = v_contract.id::text
        AND coalesce(n.meta->>'end_date', '') = to_char(v_contract.end_date::date, 'YYYY-MM-DD')
        AND n.tenant_id = v_contract.tenant_id
    ) INTO v_exists;

    IF NOT v_exists THEN
      INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
      VALUES (
        NULL, v_title, v_body,
        jsonb_build_object('type', v_type, 'contract_id', v_contract.id, 'contract_code', v_contract.code, 'end_date', v_contract.end_date::date, 'days_left', v_days_left),
        v_contract.tenant_id
      );
      v_inserted := v_inserted + 1;
    END IF;

    IF v_contract.user_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE coalesce(n.meta->>'type','') = v_type
          AND n.user_id = v_contract.user_id
          AND coalesce(n.meta->>'contract_id','') = v_contract.id::text
          AND coalesce(n.meta->>'end_date','') = to_char(v_contract.end_date::date, 'YYYY-MM-DD')
      ) INTO v_exists;

      IF NOT v_exists THEN
        INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
        VALUES (
          v_contract.user_id, v_title, v_body,
          jsonb_build_object('type', v_type, 'contract_id', v_contract.id, 'contract_code', v_contract.code, 'end_date', v_contract.end_date::date, 'days_left', v_days_left),
          v_contract.tenant_id
        );
        v_inserted := v_inserted + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN v_inserted;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_worker_visa_expiry_notifications()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_worker record;
  v_type text;
  v_title text;
  v_body text;
  v_days_left integer;
  v_exists boolean;
  v_inserted integer := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admins only';
  END IF;

  FOR v_worker IN
    SELECT id, name, visa_end, tenant_id
    FROM public.workers
    WHERE visa_end <= current_date + 30
      AND tenant_id = public.current_tenant_id()
  LOOP
    v_days_left := (v_worker.visa_end - current_date);

    IF v_days_left < 0 THEN
      v_type := 'worker_visa_expired';
      v_title := format('تأشيرة العامل %s منتهية', v_worker.name);
      v_body := format('تأشيرة العامل %s انتهت في %s', v_worker.name, to_char(v_worker.visa_end, 'YYYY-MM-DD'));
    ELSE
      v_type := 'worker_visa_expiring';
      v_title := format('تأشيرة العامل %s تنتهي قريباً', v_worker.name);
      v_body := format('تأشيرة العامل %s تنتهي خلال %s يوم', v_worker.name, v_days_left);
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE coalesce(n.meta->>'type', '') = v_type
        AND coalesce(n.meta->>'worker_id', '') = v_worker.id::text
        AND coalesce(n.meta->>'visa_end', '') = v_worker.visa_end::text
        AND n.tenant_id = v_worker.tenant_id
    ) INTO v_exists;

    IF NOT v_exists THEN
      INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
      VALUES (
        NULL, v_title, v_body,
        json_build_object('type', v_type, 'worker_id', v_worker.id, 'worker_name', v_worker.name, 'visa_end', v_worker.visa_end)::jsonb,
        v_worker.tenant_id
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN v_inserted;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_vehicle_license_expiry_notifications()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_vehicle record;
  v_type text;
  v_title text;
  v_body text;
  v_days_left integer;
  v_exists boolean;
  v_inserted integer := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admins only';
  END IF;

  FOR v_vehicle IN
    SELECT id, plate_number, license_number, license_expiry, tenant_id
    FROM public.vehicles
    WHERE license_expiry IS NOT NULL
      AND (license_expiry::date) <= current_date + 30
      AND tenant_id = public.current_tenant_id()
  LOOP
    v_days_left := (v_vehicle.license_expiry::date - current_date);

    IF v_days_left <= 0 THEN
      v_type := 'vehicle_license_expired';
      v_title := format('رخصة السيارة %s منتهية', coalesce(v_vehicle.plate_number, v_vehicle.id::text));
      v_body := format('تاريخ انتهاء رخصة السيارة %s هو %s، وقد انتهت الآن.', coalesce(v_vehicle.plate_number, v_vehicle.id::text), to_char(v_vehicle.license_expiry, 'YYYY-MM-DD'));
    ELSIF v_days_left = 15 THEN
      v_type := 'vehicle_license_expiring_15';
      v_title := format('رخصة السيارة %s تنتهي خلال 15 يومًا', coalesce(v_vehicle.plate_number, v_vehicle.id::text));
      v_body := format('متبقي 15 يومًا على انتهاء رخصة السيارة %s. تاريخ الانتهاء: %s.', coalesce(v_vehicle.plate_number, v_vehicle.id::text), to_char(v_vehicle.license_expiry, 'YYYY-MM-DD'));
    ELSIF v_days_left = 30 THEN
      v_type := 'vehicle_license_expiring_30';
      v_title := format('رخصة السيارة %s تنتهي خلال 30 يومًا', coalesce(v_vehicle.plate_number, v_vehicle.id::text));
      v_body := format('متبقي 30 يومًا على انتهاء رخصة السيارة %s. تاريخ الانتهاء: %s.', coalesce(v_vehicle.plate_number, v_vehicle.id::text), to_char(v_vehicle.license_expiry, 'YYYY-MM-DD'));
    ELSE
      CONTINUE;
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE coalesce(n.meta->>'type','') = v_type
        AND coalesce(n.meta->>'vehicle_id','') = v_vehicle.id::text
        AND coalesce(n.meta->>'license_expiry','') = to_char(v_vehicle.license_expiry::date, 'YYYY-MM-DD')
        AND n.tenant_id = v_vehicle.tenant_id
    ) INTO v_exists;

    IF NOT v_exists THEN
      INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
      VALUES (
        NULL, v_title, v_body,
        jsonb_build_object('type', v_type, 'vehicle_id', v_vehicle.id, 'plate_number', v_vehicle.plate_number, 'license_number', v_vehicle.license_number, 'license_expiry', v_vehicle.license_expiry::date, 'days_left', v_days_left),
        v_vehicle.tenant_id
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN v_inserted;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_vehicle_license_expiry_on_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text;
  v_title text;
  v_body text;
  v_days_left integer;
  v_exists boolean;
BEGIN
  IF tg_op = 'INSERT' OR (tg_op = 'UPDATE' AND (old.license_expiry IS DISTINCT FROM new.license_expiry)) THEN
    IF new.license_expiry IS NULL THEN
      RETURN new;
    END IF;

    v_days_left := (new.license_expiry::date - current_date);

    IF v_days_left <= 0 THEN
      v_type := 'vehicle_license_expired';
      v_title := format('رخصة السيارة %s منتهية', coalesce(new.plate_number, new.id::text));
      v_body := format('تاريخ انتهاء رخصة السيارة %s هو %s، وقد انتهت الآن.', coalesce(new.plate_number, new.id::text), to_char(new.license_expiry, 'YYYY-MM-DD'));
    ELSIF v_days_left = 15 THEN
      v_type := 'vehicle_license_expiring_15';
      v_title := format('رخصة السيارة %s تنتهي خلال 15 يومًا', coalesce(new.plate_number, new.id::text));
      v_body := format('متبقي 15 يومًا على انتهاء رخصة السيارة %s. تاريخ الانتهاء: %s.', coalesce(new.plate_number, new.id::text), to_char(new.license_expiry, 'YYYY-MM-DD'));
    ELSIF v_days_left = 30 THEN
      v_type := 'vehicle_license_expiring_30';
      v_title := format('رخصة السيارة %s تنتهي خلال 30 يومًا', coalesce(new.plate_number, new.id::text));
      v_body := format('متبقي 30 يومًا على انتهاء رخصة السيارة %s. تاريخ الانتهاء: %s.', coalesce(new.plate_number, new.id::text), to_char(new.license_expiry, 'YYYY-MM-DD'));
    ELSE
      RETURN new;
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE coalesce(n.meta->>'type','') = v_type
        AND coalesce(n.meta->>'vehicle_id','') = new.id::text
        AND coalesce(n.meta->>'license_expiry','') = to_char(new.license_expiry::date, 'YYYY-MM-DD')
    ) INTO v_exists;

    IF NOT v_exists THEN
      INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
      VALUES (
        NULL, v_title, v_body,
        jsonb_build_object('type', v_type, 'vehicle_id', new.id, 'plate_number', new.plate_number, 'license_number', new.license_number, 'license_expiry', new.license_expiry::date, 'days_left', v_days_left),
        new.tenant_id
      );

      IF v_days_left <= 0 AND coalesce(new.status, '') <> 'inactive' THEN
        UPDATE public.vehicles SET status = 'inactive' WHERE id = new.id;
      END IF;
    END IF;
  END IF;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_admin_on_standalone_task_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supervisor_name text;
  v_title text;
  v_type text;
  v_status_label text;
BEGIN
  IF (OLD.status IS DISTINCT FROM NEW.status) AND (NEW.status IN ('completed','cancelled')) THEN
    BEGIN
      SELECT coalesce(full_name, email, NEW.supervisor_id::text) INTO v_supervisor_name
      FROM public.users WHERE id = NEW.supervisor_id;
    EXCEPTION WHEN OTHERS THEN
      v_supervisor_name := COALESCE(NEW.supervisor_id::text, '');
    END;

    v_title := CASE WHEN NEW.status = 'completed' THEN 'انتهاء مهمة' ELSE 'إلغاء مهمة' END;
    v_type  := CASE WHEN NEW.status = 'completed' THEN 'standalone_task_completed' ELSE 'standalone_task_cancelled' END;
    v_status_label := CASE WHEN NEW.status = 'completed' THEN 'مكتملة' ELSE 'ملغاة' END;

    BEGIN
      INSERT INTO public.notifications (user_id, title, body, meta, tenant_id)
      VALUES (
        NULL,
        v_title || ' — ' || COALESCE(NEW.title, NEW.id::text),
        format('%s قام بتغيير حالة المهمة %s إلى %s', coalesce(v_supervisor_name, 'مشرف'), coalesce(NEW.title::text, NEW.id::text), v_status_label),
        jsonb_build_object('type', v_type, 'task_id', NEW.id::text, 'status', NEW.status, 'supervisor_id', NEW.supervisor_id::text),
        NEW.tenant_id
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.evaluate_payment_due_notification(p_payment_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment   record;
  v_days_left integer;
  v_type      text;
  v_title     text;
  v_body      text;
  v_exists    boolean;
  v_admin_id  uuid;
BEGIN
  SELECT
    cp.id, cp.amount, cp.due_date, cp.contract_id, cp.tenant_id,
    c.user_id AS client_id, c.code AS contract_code
  INTO v_payment
  FROM contract_payments cp
  JOIN contracts c ON c.id = cp.contract_id
  WHERE cp.id = p_payment_id
    AND cp.due_date IS NOT NULL
    AND (cp.gateway_status IS NULL OR cp.gateway_status IN ('pending', 'failed', 'cancelled'));

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_days_left := (v_payment.due_date - current_date);

  IF v_days_left > 3 THEN
    RETURN NULL;
  ELSIF v_days_left < 0 THEN
    v_type  := 'payment_late';
    v_title := 'دفعة متأخرة';
    v_body  := format('مبلغ %s KWD متأخر عن السداد منذ %s يوم (عقد %s)',
                      to_char(v_payment.amount, 'FM999999990.000'), abs(v_days_left), coalesce(v_payment.contract_code, ''));
  ELSE
    CASE v_days_left
      WHEN 3 THEN
        v_type  := 'payment_due_3';
        v_title := 'تذكير: دفعة مستحقة خلال 3 أيام';
        v_body  := format('مبلغ %s KWD مستحق في %s', to_char(v_payment.amount, 'FM999999990.000'), to_char(v_payment.due_date, 'DD/MM/YYYY'));
      WHEN 1 THEN
        v_type  := 'payment_due_1';
        v_title := 'تذكير: دفعة مستحقة غداً';
        v_body  := format('مبلغ %s KWD مستحق غداً — استعد للدفع', to_char(v_payment.amount, 'FM999999990.000'));
      WHEN 0 THEN
        v_type  := 'payment_due_today';
        v_title := 'طلب دفع مستحق اليوم';
        v_body  := format('مبلغ %s KWD — اضغط للدفع الآن', to_char(v_payment.amount, 'FM999999990.000'));
      ELSE
        RETURN NULL;
    END CASE;
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM notifications n WHERE n.meta->>'type' = v_type AND n.meta->>'payment_id' = v_payment.id::text
  ) INTO v_exists;

  IF v_exists OR v_payment.client_id IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO notifications(user_id, title, body, meta, tenant_id)
  VALUES(
    v_payment.client_id, v_title, v_body,
    jsonb_build_object('type', v_type, 'payment_id', v_payment.id, 'contract_id', v_payment.contract_id, 'contract_code', v_payment.contract_code, 'amount', v_payment.amount, 'due_date', to_char(v_payment.due_date, 'YYYY-MM-DD')),
    v_payment.tenant_id
  );

  IF v_type = 'payment_late' THEN
    FOR v_admin_id IN
      SELECT u.id FROM user_roles ur JOIN roles r ON r.id = ur.role_id JOIN users u ON u.id = ur.user_id
      WHERE r.name = 'admin' AND u.tenant_id = v_payment.tenant_id
    LOOP
      SELECT EXISTS(
        SELECT 1 FROM notifications n
        WHERE n.user_id = v_admin_id AND n.meta->>'type' = 'payment_late_admin' AND n.meta->>'payment_id' = v_payment.id::text
      ) INTO v_exists;

      IF NOT v_exists THEN
        INSERT INTO notifications(user_id, title, body, meta, tenant_id)
        VALUES(
          v_admin_id, 'دفعة متأخرة',
          format('دفعة بقيمة %s KWD متأخرة عن السداد (عقد %s)', to_char(v_payment.amount, 'FM999999990.000'), coalesce(v_payment.contract_code, '')),
          jsonb_build_object('type', 'payment_late_admin', 'payment_id', v_payment.id, 'contract_id', v_payment.contract_id, 'contract_code', v_payment.contract_code, 'amount', v_payment.amount),
          v_payment.tenant_id
        );
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('type', v_type, 'client_id', v_payment.client_id, 'contract_id', v_payment.contract_id, 'amount', v_payment.amount);
END;
$$;

GRANT EXECUTE ON FUNCTION public.evaluate_payment_due_notification(uuid) TO service_role;

-- ═══════════════════════════════════════════════════════════════════════
-- 21. Supervisor RPCs — SECURITY DEFINER bypasses RLS, so the tenant check
--     has to be inline in the query itself.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_late_contract_ids_for_supervisor()
RETURNS TABLE(contract_id uuid)
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT cp.contract_id
  FROM contract_payments cp
  JOIN contracts c ON c.id = cp.contract_id
  JOIN zones z ON z.id = c.zone_id
  JOIN users me ON me.id = auth.uid()
  WHERE cp.due_date IS NOT NULL
    AND cp.due_date < current_date
    AND (cp.gateway_status IS NULL OR cp.gateway_status IN ('pending', 'failed', 'cancelled'))
    AND z.line_id = me.assigned_line_id
    AND c.tenant_id = me.tenant_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_late_contract_ids_for_supervisor() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_contract_payments_for_supervisor(p_contract_id uuid)
RETURNS TABLE(
  id uuid, amount numeric, payment_method text, payment_date date, due_date date,
  gateway_status text, notes text, created_at timestamptz
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT cp.id, cp.amount, cp.payment_method, cp.payment_date, cp.due_date, cp.gateway_status, cp.notes, cp.created_at
  FROM contract_payments cp
  JOIN contracts c ON c.id = cp.contract_id
  JOIN zones z ON z.id = c.zone_id
  JOIN users me ON me.id = auth.uid()
  WHERE cp.contract_id = p_contract_id
    AND z.line_id = me.assigned_line_id
    AND c.tenant_id = me.tenant_id
  ORDER BY cp.due_date ASC NULLS LAST, cp.payment_date DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_contract_payments_for_supervisor(uuid) TO authenticated;
