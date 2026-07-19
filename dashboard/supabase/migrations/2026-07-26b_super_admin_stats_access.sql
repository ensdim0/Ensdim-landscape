-- Read-only access for the platform-admin app's company detail view
-- (contract counts). SELECT-only, and the app only ever asks for
-- head:true counts (no row bodies cross the wire), but scope it to
-- is_super_admin() regardless — never full-access.

DROP POLICY IF EXISTS "Super admins read contracts" ON public.contracts;
CREATE POLICY "Super admins read contracts" ON public.contracts
  FOR SELECT
  USING (public.is_super_admin());
