-- Multi-tenant SaaS conversion — platform-owner (super-admin) support.
--
-- Adds a platform-level flag (orthogonal to the per-tenant admin/supervisor/
-- client role) that lets you manage all companies from a separate app,
-- without giving that role visibility into any single tenant's business
-- data (contracts, clients, payments, etc. all stay scoped to their own
-- tenant via the RLS from the previous migration).

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_platform_owner boolean NOT NULL DEFAULT false;

-- Only an existing platform owner (or service_role) may grant/revoke the
-- flag on someone else — prevents a regular admin from self-promoting.
REVOKE UPDATE (is_platform_owner) ON public.users FROM authenticated;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.is_platform_owner = true
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated, service_role;

-- Platform owners can see and manage every tenant row (list/suspend/
-- activate/create via edge function). Regular tenant admins keep their
-- existing "read own tenant only" policy from the foundation migration.
DROP POLICY IF EXISTS "Super admins manage tenants" ON public.tenants;
CREATE POLICY "Super admins manage tenants" ON public.tenants
  FOR ALL
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

GRANT INSERT, UPDATE, DELETE ON public.tenants TO authenticated;

-- Platform owners can see a lightweight roster of users across all tenants
-- (needed for the companies dashboard to show "N users" per company, list
-- each company's admin, etc.) without exposing tenant business data.
DROP POLICY IF EXISTS "Super admins read all users" ON public.users;
CREATE POLICY "Super admins read all users" ON public.users
  FOR SELECT
  USING (public.is_super_admin());

-- To make yourself a platform owner, run (as service_role / SQL editor):
--   update public.users set is_platform_owner = true where email = 'your-login-email@example.com';
