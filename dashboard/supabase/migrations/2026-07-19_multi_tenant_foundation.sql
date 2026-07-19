-- Multi-tenant SaaS conversion — Phase 1: schema foundation.
--
-- Adds a `tenants` table plus a `tenant_id` column on every tenant-owned table,
-- backfills all existing rows to a single "Ensdim" tenant, and introduces
-- `public.current_tenant_id()` as the building block future RLS policies will
-- use (mirrors how `public.is_admin()` already centralizes the role check).
--
-- This migration only adds columns/tables and backfills data — it does NOT
-- change any existing RLS policy yet (that is Phase 2, a separate migration),
-- so behavior for the existing Ensdim tenant is unaffected. Safe to re-run.

-- ═══════════════════════════════════════════════════════════════════════
-- 1. TENANTS TABLE
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'trial')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_tenants_updated ON public.tenants;
CREATE TRIGGER trg_tenants_updated
  BEFORE UPDATE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

GRANT SELECT ON public.tenants TO authenticated;
GRANT ALL ON public.tenants TO service_role;

-- Seed the single tenant that owns all data existing today. Fixed UUID so
-- the rest of this migration (and any manual follow-up) can reference it
-- deterministically.
INSERT INTO public.tenants (id, name, slug, status)
VALUES ('faf164d1-64f3-4b35-99c7-242118dd76c5', 'Ensdim', 'ensdim', 'active')
ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- 2. tenant_id COLUMN ON EVERY TENANT-OWNED TABLE
-- ═══════════════════════════════════════════════════════════════════════
-- `notifications`, `device_tokens` and `audit_logs` are deliberately excluded
-- — their tenant is always derivable through their `user_id`/`actor_id` FK,
-- so they don't need their own column.

DO $$
DECLARE
  ensdim_tenant_id CONSTANT uuid := 'faf164d1-64f3-4b35-99c7-242118dd76c5';
  t text;
  fkname text;
  idxname text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users', 'geographic_lines', 'zones', 'blocks', 'contract_types', 'contracts',
    'assets', 'visits', 'contract_tasks', 'task_executions', 'task_photos',
    'visit_photos', 'client_comments', 'supervisor_notes', 'assignments', 'reports',
    'contract_status_requests', 'standalone_tasks', 'standalone_task_payments',
    'invoices', 'payments', 'contract_payments', 'company_phones', 'vehicles',
    'vehicle_expenses', 'workers', 'company_expenses', 'expense_sections',
    'expense_line_items', 'contact_requests'
  ]
  LOOP
    fkname := t || '_tenant_id_fkey';
    idxname := 'idx_' || t || '_tenant_id';

    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS tenant_id uuid', t);
    EXECUTE format('UPDATE public.%I SET tenant_id = %L WHERE tenant_id IS NULL', t, ensdim_tenant_id);
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN tenant_id SET NOT NULL', t);

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = fkname) THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (tenant_id) REFERENCES public.tenants(id)',
        t, fkname
      );
    END IF;

    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I (tenant_id)', idxname, t);
  END LOOP;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- 3. current_tenant_id() — the choke point Phase 2's RLS rewrite will use
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT tenant_id FROM public.users WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.current_tenant_id() TO authenticated, service_role;

DROP POLICY IF EXISTS "Authenticated read own tenant" ON public.tenants;
CREATE POLICY "Authenticated read own tenant"
  ON public.tenants
  FOR SELECT
  TO authenticated
  USING (id = public.current_tenant_id());

-- No insert/update/delete policy for `authenticated` on purpose: tenant
-- creation/suspension is a platform-owner (service_role) operation only,
-- matching the decision to keep onboarding manual for now.

-- ═══════════════════════════════════════════════════════════════════════
-- 4. handle_new_user() — stamp tenant_id on every newly created auth user
-- ═══════════════════════════════════════════════════════════════════════
-- Reads tenant_id from auth signup metadata (`raw_user_meta_data->>'tenant_id'`)
-- so a future updated `admin-create-user` edge function (Phase 4) can pass the
-- calling admin's own tenant explicitly. Until that edge function is updated,
-- or for any signup that omits it, this defaults to the Ensdim tenant — safe
-- today because Ensdim is still the only tenant in the system.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  client_role_id uuid;
  new_tenant_id uuid;
BEGIN
  new_tenant_id := NULLIF(new.raw_user_meta_data->>'tenant_id', '')::uuid;
  IF new_tenant_id IS NULL THEN
    new_tenant_id := 'faf164d1-64f3-4b35-99c7-242118dd76c5';
  END IF;

  INSERT INTO public.users (id, email, phone, full_name, tenant_id)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'fullName', 'New User'),
    new_tenant_id
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
