-- Self-service company signup, gated behind super-admin approval.
--
-- Lets a prospective customer register their own company from a public
-- dashboard page (supabase.auth.signUp — triggers Supabase's normal email
-- confirmation flow, no edge function/service-role key involved). The new
-- tenant is created with status 'pending' instead of 'active', so once the
-- user confirms their email they can log in but see an "awaiting approval"
-- screen instead of the real app — current_tenant_id() now blocks 'pending'
-- exactly like it already blocks 'suspended' (2026-07-27), so every RLS
-- policy in the system stays locked out until a platform owner flips the
-- tenant to 'active' from platform-admin (plain UPDATE — already covered by
-- the "Super admins manage tenants" policy from 2026-07-22).

-- ═══════════════════════════════════════════════════════════════════════
-- 1. Allow 'pending' as a tenant status
-- ═══════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  con record;
BEGIN
  FOR con IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'tenants' AND c.contype = 'c' AND pg_get_constraintdef(c.oid) ILIKE '%status%'
  LOOP
    EXECUTE format('ALTER TABLE public.tenants DROP CONSTRAINT %I', con.conname);
  END LOOP;
END;
$$;

ALTER TABLE public.tenants
  ADD CONSTRAINT tenants_status_check CHECK (status IN ('active', 'suspended', 'trial', 'pending'));

-- ═══════════════════════════════════════════════════════════════════════
-- 2. Block access for pending tenants the same way suspended ones are blocked
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.tenant_id
  FROM public.users u
  JOIN public.tenants t ON t.id = u.tenant_id
  WHERE u.id = auth.uid()
    AND t.status NOT IN ('suspended', 'pending');
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- 3. Slug helpers for tenants created from the public signup form
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.slugify_text(input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT NULLIF(regexp_replace(regexp_replace(lower(trim(input)), '[^a-z0-9]+', '-', 'g'), '^-+|-+$', '', 'g'), '')
$$;

CREATE OR REPLACE FUNCTION public.generate_unique_tenant_slug(base_name text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  base text;
  candidate text;
  n int := 0;
BEGIN
  base := public.slugify_text(base_name);
  IF base IS NULL THEN
    base := 'company-' || substr(md5(random()::text), 1, 8);
  END IF;

  candidate := base;
  WHILE EXISTS (SELECT 1 FROM public.tenants WHERE slug = candidate) LOOP
    n := n + 1;
    candidate := base || '-' || n;
  END LOOP;

  RETURN candidate;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- 4. handle_new_user() — create a new pending tenant + admin when the
--    signup carries `new_company_name` metadata (the public signup form).
--    Any other signup (admin-create-user, platform-create-company, regular
--    client self-registration) is untouched — same tenant_id/role logic as
--    before.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  client_role_id uuid;
  admin_role_id uuid;
  assigned_role_id uuid;
  new_tenant_id uuid;
  company_name text;
BEGIN
  company_name := NULLIF(trim(new.raw_user_meta_data->>'new_company_name'), '');

  IF company_name IS NOT NULL THEN
    INSERT INTO public.tenants (name, slug, status)
    VALUES (company_name, public.generate_unique_tenant_slug(company_name), 'pending')
    RETURNING id INTO new_tenant_id;
  ELSE
    new_tenant_id := NULLIF(new.raw_user_meta_data->>'tenant_id', '')::uuid;
    IF new_tenant_id IS NULL THEN
      new_tenant_id := 'faf164d1-64f3-4b35-99c7-242118dd76c5';
    END IF;
  END IF;

  INSERT INTO public.users (id, email, phone, full_name, tenant_id)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'fullName', 'New User'),
    new_tenant_id
  );

  IF company_name IS NOT NULL THEN
    SELECT id INTO admin_role_id FROM public.roles WHERE name = 'admin';
    assigned_role_id := admin_role_id;
  ELSE
    SELECT id INTO client_role_id FROM public.roles WHERE name = 'client';
    assigned_role_id := client_role_id;
  END IF;

  IF assigned_role_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role_id)
    VALUES (new.id, assigned_role_id)
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reminder: this migration assumes Supabase Auth → Providers → Email →
-- "Confirm email" is switched ON for this project. That toggle lives in the
-- Supabase dashboard (not in SQL) and is what actually forces email
-- confirmation before signInWithPassword succeeds.
