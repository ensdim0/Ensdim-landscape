-- ⚠️ DEPRECATED — DO NOT RUN. Frozen at 2026-02-18, predates ~90 later
-- migrations (multi-tenancy, payments, notifications, fleet, workers, ...).
-- Kept only for historical reference. The real schema = every file in
-- dashboard/supabase/migrations/ applied in order, starting from this
-- snapshot's contents. To rebuild a fresh project, use Supabase's own
-- migration tooling against that folder instead of pasting this file.
--
-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  FULL DATABASE REBUILD - Final Schema State (2026-02-18)          ║
-- ║  Run this in Supabase SQL Editor to recreate everything           ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ── Extensions ──
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════════════
-- 1. TABLES (Correct dependency order)
-- ═══════════════════════════════════════════════════════════════════════

-- Roles
CREATE TABLE IF NOT EXISTS public.roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Users (extends auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  assigned_line_id UUID,  -- FK added after geographic_lines
  assignment_start_date DATE,
  assignment_end_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- User Roles
CREATE TABLE IF NOT EXISTS public.user_roles (
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  role_id UUID REFERENCES public.roles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id)
);

-- Contract Types
CREATE TABLE IF NOT EXISTS public.contract_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  terms JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Company Phones
CREATE TABLE IF NOT EXISTS public.company_phones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number TEXT NOT NULL,
  phone_name TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Geographic Lines (uses status text, NOT is_active boolean)
CREATE TABLE IF NOT EXISTS public.geographic_lines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  line_type TEXT NOT NULL,
  contract_type_id UUID REFERENCES public.contract_types(id) ON DELETE SET NULL,
  phone_number TEXT,
  car_number TEXT,
  vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
  phone_id UUID REFERENCES public.company_phones(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add FK from users to geographic_lines
ALTER TABLE public.users 
  ADD CONSTRAINT users_assigned_line_id_fkey 
  FOREIGN KEY (assigned_line_id) REFERENCES public.geographic_lines(id) ON DELETE SET NULL;

-- Zones
CREATE TABLE IF NOT EXISTS public.zones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  line_id UUID REFERENCES public.geographic_lines(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Blocks
CREATE TABLE IF NOT EXISTS public.blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  zone_id UUID REFERENCES public.zones(id) ON DELETE RESTRICT,
  code TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (zone_id, code)
);

-- Contracts (user_id references users directly, no clients table)
CREATE TABLE IF NOT EXISTS public.contracts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE RESTRICT,
  block_id UUID REFERENCES public.blocks(id) ON DELETE SET NULL,
  zone_id UUID REFERENCES public.zones(id) ON DELETE SET NULL,
  code TEXT NOT NULL UNIQUE,
  contract_type_id UUID REFERENCES public.contract_types(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending', 'expired', 'terminated', 'cancelled')),
  duration_months INTEGER NOT NULL DEFAULT 12,
  address_details TEXT,
  block_number TEXT,
  street TEXT,
  avenue TEXT,
  house TEXT,
  kuwait_finder_url TEXT,
  contract_user_name TEXT,
  contract_user_phone TEXT,
  contract_user_password_hash TEXT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  total_value NUMERIC(12,2) NOT NULL DEFAULT 0,
  pdf_path TEXT,
  terms JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Visits (belongs to contract)
CREATE TABLE IF NOT EXISTS public.visits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
  visit_date DATE NOT NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Contract Tasks (belongs to visit)
CREATE TABLE IF NOT EXISTS public.contract_tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
  visit_id UUID REFERENCES public.visits(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'verified', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Assets
CREATE TABLE IF NOT EXISTS public.assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contract_id UUID REFERENCES public.contracts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  serial_number TEXT,
  asset_type TEXT,
  quantity INTEGER NOT NULL DEFAULT 1,
  size_class TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Task Executions
CREATE TABLE IF NOT EXISTS public.task_executions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID REFERENCES public.contract_tasks(id) ON DELETE CASCADE,
  visit_id UUID REFERENCES public.visits(id) ON DELETE SET NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'completed',
  gps_lat NUMERIC(10,7),
  gps_lng NUMERIC(10,7),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Task Photos
CREATE TABLE IF NOT EXISTS public.task_photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  execution_id UUID REFERENCES public.task_executions(id) ON DELETE CASCADE,
  photo_path TEXT NOT NULL,
  photo_type TEXT NOT NULL DEFAULT 'before',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Assignments
CREATE TABLE IF NOT EXISTS public.assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  line_id UUID REFERENCES public.geographic_lines(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Reports
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visits(id) ON DELETE CASCADE,
  summary TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Invoices
CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contract_id UUID REFERENCES public.contracts(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'issued',
  due_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Payments
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_id UUID REFERENCES public.invoices(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  paid_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  method TEXT NOT NULL,
  reference TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Audit Logs
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity TEXT NOT NULL,
  entity_id UUID,
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Vehicles (Fleet Management)
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  plate_number TEXT NOT NULL,
  license_number TEXT NOT NULL,
  license_expiry DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Vehicle Expenses
CREATE TABLE IF NOT EXISTS public.vehicle_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  amount NUMERIC(12, 3) NOT NULL DEFAULT 0,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════════
-- 2. INDEXES
-- ═══════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_contracts_type ON public.contracts(contract_type_id);
CREATE INDEX IF NOT EXISTS idx_contracts_user ON public.contracts(user_id);
CREATE INDEX IF NOT EXISTS idx_contracts_zone ON public.contracts(zone_id);
CREATE INDEX IF NOT EXISTS idx_visits_contract_id ON public.visits(contract_id);
CREATE INDEX IF NOT EXISTS idx_visits_status ON public.visits(status);
CREATE INDEX IF NOT EXISTS idx_visits_visit_date ON public.visits(visit_date);
CREATE INDEX IF NOT EXISTS idx_contract_tasks_contract_id ON public.contract_tasks(contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_tasks_visit_id ON public.contract_tasks(visit_id);
CREATE INDEX IF NOT EXISTS idx_contract_tasks_status ON public.contract_tasks(status);
CREATE INDEX IF NOT EXISTS idx_contract_tasks_month ON public.contract_tasks(month);
CREATE INDEX IF NOT EXISTS idx_executions_task ON public.task_executions(task_id);
CREATE INDEX IF NOT EXISTS idx_photos_execution ON public.task_photos(execution_id);
CREATE INDEX IF NOT EXISTS idx_lines_contract_type ON public.geographic_lines(contract_type_id);
CREATE INDEX IF NOT EXISTS idx_lines_phone_id ON public.geographic_lines(phone_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_expenses_vehicle_id ON public.vehicle_expenses(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_expenses_date ON public.vehicle_expenses(expense_date);

-- ═══════════════════════════════════════════════════════════════════════
-- 3. VIEWS
-- ═══════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.users_view CASCADE;
DROP VIEW IF EXISTS public.contracts_view CASCADE;
DROP VIEW IF EXISTS public.invoices_view CASCADE;

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
  c.block_number,
  c.street,
  c.avenue,
  c.house,
  c.kuwait_finder_url,
  c.contract_user_name,
  c.contract_user_phone,
  c.start_date,
  c.end_date,
  c.total_value,
  c.terms,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  coalesce(c.zone_id, b.zone_id) AS zone_id,
  z.line_id,
  u.full_name AS client_name,
  u.email AS client_email
FROM public.contracts c
LEFT JOIN public.blocks b ON b.id = c.block_id
LEFT JOIN public.zones z ON z.id = coalesce(c.zone_id, b.zone_id)
LEFT JOIN public.users u ON u.id = c.user_id
WHERE c.deleted_at IS NULL;

CREATE VIEW public.invoices_view AS
SELECT i.*
FROM public.invoices i
WHERE i.deleted_at IS NULL;

-- ═══════════════════════════════════════════════════════════════════════
-- 4. FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════

-- Admin check function (SECURITY DEFINER to bypass RLS recursion)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles ur
    JOIN public.roles r ON ur.role_id = r.id
    WHERE ur.user_id = auth.uid() AND r.name = 'admin'
  );
$$;

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  new.updated_at = now();
  RETURN new;
END;
$$ LANGUAGE plpgsql;

-- Auth handler: auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  client_role_id UUID;
BEGIN
  INSERT INTO public.users (id, email, phone, full_name)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'fullName', 'New User')
  );

  SELECT id INTO client_role_id FROM public.roles WHERE name = 'client';
  IF client_role_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role_id)
    VALUES (new.id, client_role_id)
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════
-- 5. TRIGGERS
-- ═══════════════════════════════════════════════════════════════════════

-- Apply updated_at trigger to all tables that have the column
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables tbl ON c.table_schema = tbl.table_schema AND c.table_name = tbl.table_name
    WHERE c.column_name = 'updated_at'
      AND c.table_schema = 'public'
      AND tbl.table_type = 'BASE TABLE'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_updated ON %I', t, t);
    EXECUTE format('CREATE TRIGGER trg_%I_updated BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', t, t);
  END LOOP;
END;
$$;

-- Auth trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ═══════════════════════════════════════════════════════════════════════
-- 6. SEED DATA
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO public.roles (name) VALUES ('admin'), ('supervisor'), ('client')
ON CONFLICT (name) DO NOTHING;

-- Backfill public.users from auth.users
INSERT INTO public.users (id, email, phone, full_name)
SELECT id, email, raw_user_meta_data->>'phone', coalesce(raw_user_meta_data->>'fullName', 'User')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.resolve_login_email(login_identifier text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.email
  FROM public.users u
  WHERE lower(u.email) = lower(trim(login_identifier))
     OR regexp_replace(coalesce(u.phone, ''), '[^0-9+]', '', 'g') = regexp_replace(coalesce(trim(login_identifier), ''), '[^0-9+]', '', 'g')
  ORDER BY CASE WHEN lower(u.email) = lower(trim(login_identifier)) THEN 0 ELSE 1 END
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_login_email(text) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════
-- 7. PRIVILEGES
-- ═══════════════════════════════════════════════════════════════════════

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;

GRANT SELECT ON public.users_view TO authenticated;
GRANT SELECT ON public.contracts_view TO authenticated;
GRANT SELECT ON public.invoices_view TO authenticated;

GRANT ALL ON public.users TO service_role;
GRANT ALL ON public.roles TO service_role;
GRANT ALL ON public.user_roles TO service_role;
GRANT ALL ON public.contract_tasks TO service_role;
GRANT ALL ON public.visits TO service_role;
GRANT ALL ON public.visits TO authenticated;
GRANT ALL ON public.contract_tasks TO authenticated;
GRANT ALL ON public.vehicles TO service_role;
GRANT ALL ON public.vehicles TO authenticated;
GRANT ALL ON public.vehicle_expenses TO service_role;
GRANT ALL ON public.vehicle_expenses TO authenticated;
GRANT ALL ON public.company_phones TO service_role;
GRANT ALL ON public.company_phones TO authenticated;

GRANT EXECUTE ON FUNCTION public.is_admin TO authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════
-- 8. ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════

-- Enable RLS on all tables
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END;
$$;

-- Roles
DROP POLICY IF EXISTS "Read access for all" ON public.roles;
CREATE POLICY "Read access for all" ON public.roles FOR SELECT USING (true);

-- User Roles
DROP POLICY IF EXISTS "Read access for own role" ON public.user_roles;
CREATE POLICY "Read access for own role" ON public.user_roles FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Admins manage roles" ON public.user_roles;
CREATE POLICY "Admins manage roles" ON public.user_roles FOR ALL USING (public.is_admin());

-- Users
DROP POLICY IF EXISTS "Read own profile" ON public.users;
CREATE POLICY "Read own profile" ON public.users FOR SELECT USING (id = auth.uid());
DROP POLICY IF EXISTS "Update own profile" ON public.users;
CREATE POLICY "Update own profile" ON public.users FOR UPDATE USING (id = auth.uid());
DROP POLICY IF EXISTS "Admins manage users" ON public.users;
CREATE POLICY "Admins manage users" ON public.users FOR ALL USING (public.is_admin());

-- Geographic Lines
DROP POLICY IF EXISTS "Admins full access lines" ON public.geographic_lines;
CREATE POLICY "Admins full access lines" ON public.geographic_lines FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Authenticated read lines" ON public.geographic_lines;
CREATE POLICY "Authenticated read lines" ON public.geographic_lines FOR SELECT TO authenticated USING (true);

-- Zones
DROP POLICY IF EXISTS "Admins full access zones" ON public.zones;
CREATE POLICY "Admins full access zones" ON public.zones FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Authenticated read zones" ON public.zones;
CREATE POLICY "Authenticated read zones" ON public.zones FOR SELECT TO authenticated USING (true);

-- Blocks
DROP POLICY IF EXISTS "Admins full access blocks" ON public.blocks;
CREATE POLICY "Admins full access blocks" ON public.blocks FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Authenticated read blocks" ON public.blocks;
CREATE POLICY "Authenticated read blocks" ON public.blocks FOR SELECT TO authenticated USING (true);

-- Contract Types
DROP POLICY IF EXISTS "Admins full access contract_types" ON public.contract_types;
CREATE POLICY "Admins full access contract_types" ON public.contract_types FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Authenticated read contract_types" ON public.contract_types;
CREATE POLICY "Authenticated read contract_types" ON public.contract_types FOR SELECT TO authenticated USING (true);

-- Contracts
DROP POLICY IF EXISTS "Admins full access contracts" ON public.contracts;
CREATE POLICY "Admins full access contracts" ON public.contracts FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Clients read own contracts" ON public.contracts;
CREATE POLICY "Clients read own contracts" ON public.contracts FOR SELECT USING (user_id = auth.uid());

-- Visits
DROP POLICY IF EXISTS "Admins full access visits" ON public.visits;
DROP POLICY IF EXISTS "admin_all_visits" ON public.visits;
CREATE POLICY "admin_all_visits" ON public.visits FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
);
DROP POLICY IF EXISTS "supervisor_read_visits" ON public.visits;
CREATE POLICY "supervisor_read_visits" ON public.visits FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    WHERE u.id = auth.uid() AND c.id = visits.contract_id
  )
);

-- Contract Tasks
DROP POLICY IF EXISTS "Admins full access tasks" ON public.contract_tasks;
DROP POLICY IF EXISTS "admin_all_contract_tasks" ON public.contract_tasks;
CREATE POLICY "admin_all_contract_tasks" ON public.contract_tasks FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
);
DROP POLICY IF EXISTS "supervisor_read_contract_tasks" ON public.contract_tasks;
CREATE POLICY "supervisor_read_contract_tasks" ON public.contract_tasks FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    WHERE u.id = auth.uid() AND c.id = contract_tasks.contract_id
  )
);
DROP POLICY IF EXISTS "supervisor_update_contract_tasks" ON public.contract_tasks;
CREATE POLICY "supervisor_update_contract_tasks" ON public.contract_tasks FOR UPDATE TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.zones z ON z.line_id = u.assigned_line_id
    JOIN public.contracts c ON c.zone_id = z.id
    WHERE u.id = auth.uid() AND c.id = contract_tasks.contract_id
  )
);

-- Task Executions
DROP POLICY IF EXISTS "Admins full access executions" ON public.task_executions;
CREATE POLICY "Admins full access executions" ON public.task_executions FOR ALL USING (public.is_admin());

-- Task Photos
DROP POLICY IF EXISTS "Admins full access photos" ON public.task_photos;
CREATE POLICY "Admins full access photos" ON public.task_photos FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Authenticated read photos" ON public.task_photos;
CREATE POLICY "Authenticated read photos" ON public.task_photos FOR SELECT TO authenticated USING (true);

-- Invoices
DROP POLICY IF EXISTS "Admins full access invoices" ON public.invoices;
CREATE POLICY "Admins full access invoices" ON public.invoices FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Clients read own invoices" ON public.invoices;
CREATE POLICY "Clients read own invoices" ON public.invoices FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.contracts ct WHERE ct.id = invoices.contract_id AND ct.user_id = auth.uid())
);

-- Vehicles
DROP POLICY IF EXISTS "admin_all_vehicles" ON public.vehicles;
CREATE POLICY "admin_all_vehicles" ON public.vehicles FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
);

-- Vehicle Expenses
DROP POLICY IF EXISTS "admin_all_vehicle_expenses" ON public.vehicle_expenses;
CREATE POLICY "admin_all_vehicle_expenses" ON public.vehicle_expenses FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
);

-- Company Phones
DROP POLICY IF EXISTS "admin_all_company_phones" ON public.company_phones;
CREATE POLICY "admin_all_company_phones" ON public.company_phones FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.name = 'admin')
);

-- ═══════════════════════════════════════════════════════════════════════
-- 9. STORAGE
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public) VALUES ('task-photos', 'task-photos', false) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('attachments', 'attachments', true) ON CONFLICT DO NOTHING;
UPDATE storage.buckets SET public = false WHERE id = 'task-photos';

DROP POLICY IF EXISTS "Public Access to task photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated read task photos" ON storage.objects;
CREATE POLICY "Authenticated read task photos" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'task-photos');

DROP POLICY IF EXISTS "Auth users upload task photos" ON storage.objects;
CREATE POLICY "Auth users upload task photos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'task-photos' AND auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════
-- 10. OPTIONAL DEV ADMIN BOOTSTRAP (OPT-IN)
-- ═══════════════════════════════════════════════════════════════════════
-- To enable locally only: select set_config('app.enable_dev_admin_bootstrap', 'true', false);

DO $$
DECLARE
  enable_dev_admin_bootstrap BOOLEAN := coalesce(current_setting('app.enable_dev_admin_bootstrap', true), 'false') = 'true';
  user_rec RECORD;
  admin_role_id UUID;
BEGIN
  IF NOT enable_dev_admin_bootstrap THEN
    RAISE NOTICE 'Skipping dev admin bootstrap. Set app.enable_dev_admin_bootstrap=true to enable explicitly.';
    RETURN;
  END IF;

  SELECT id INTO admin_role_id FROM public.roles WHERE name = 'admin';
  IF admin_role_id IS NOT NULL THEN
    FOR user_rec IN SELECT id, email, raw_user_meta_data FROM auth.users LOOP
      INSERT INTO public.users (id, email, full_name)
      VALUES (
        user_rec.id,
        user_rec.email,
        coalesce(user_rec.raw_user_meta_data->>'fullName', 'Dev User')
      )
      ON CONFLICT (id) DO NOTHING;

      INSERT INTO public.user_roles (user_id, role_id)
      VALUES (user_rec.id, admin_role_id)
      ON CONFLICT (user_id, role_id) DO NOTHING;
    END LOOP;
  END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- DONE! Database fully rebuilt.
-- ═══════════════════════════════════════════════════════════════════════
