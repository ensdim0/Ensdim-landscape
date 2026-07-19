-- The "suspend" toggle in platform-admin only flipped tenants.status — it
-- was never actually checked anywhere, so a suspended company's admin could
-- keep logging in and working completely normally. Fix this centrally:
-- current_tenant_id() now returns NULL for a suspended tenant's users
-- instead of their real tenant_id. Since virtually every RLS policy in the
-- system does `tenant_id = public.current_tenant_id()`, a NULL result makes
-- every one of those checks fail at once — blocking all reads/writes to
-- contracts, visits, zones, payments, etc. for that tenant, without having
-- to touch each policy individually.
--
-- Practical effect: the dashboard's users_view lookup also returns no row
-- for a suspended tenant's user, so fetchUserRole() falls back to role
-- "client" and the admin-only route guard bounces them back to /login —
-- i.e. they're logged out of the app in practice, even though their
-- Supabase Auth password still technically works.

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
    AND t.status <> 'suspended';
$$;
