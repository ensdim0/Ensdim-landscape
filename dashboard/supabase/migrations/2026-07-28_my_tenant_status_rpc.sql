-- Lets a logged-in user check their OWN tenant's status even when it's
-- suspended (current_tenant_id() deliberately returns NULL in that case,
-- which is exactly why we need a separate, unfiltered lookup here) — so
-- the dashboard/mobile app can show a proper "your company is suspended"
-- screen instead of just silently failing to load any data.

CREATE OR REPLACE FUNCTION public.my_tenant_status()
RETURNS TABLE(tenant_id uuid, tenant_name text, status text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT t.id, t.name, t.status
  FROM public.users u
  JOIN public.tenants t ON t.id = u.tenant_id
  WHERE u.id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.my_tenant_status() TO authenticated;
