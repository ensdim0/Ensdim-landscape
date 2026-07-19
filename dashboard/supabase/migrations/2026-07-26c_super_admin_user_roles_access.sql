-- The company detail view in platform-admin needs to list a tenant's admins
-- (joins user_roles -> roles -> users). "Admins manage roles" only lets a
-- caller see roles for users in THEIR OWN tenant, so a platform owner
-- viewing a DIFFERENT company always got an empty admin list. Add explicit
-- read access for platform owners, same pattern as "Super admins read all
-- users" / "Super admins read contracts".

DROP POLICY IF EXISTS "Super admins read user_roles" ON public.user_roles;
CREATE POLICY "Super admins read user_roles" ON public.user_roles
  FOR SELECT
  USING (public.is_super_admin());
