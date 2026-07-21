-- Security fix: handle_new_user() no longer trusts a client-supplied
-- `tenant_id` in auth signup metadata.
--
-- Previously, any signup without `new_company_name` fell back to reading
-- `raw_user_meta_data->>'tenant_id'` and joining that tenant directly as a
-- 'client'. That path was only ever meant for the internal
-- admin-create-user Edge Function (which computed tenant_id safely
-- server-side from the calling admin's own profile) — but the trigger has
-- no way to tell that call apart from anyone using the public anon key
-- (e.g. from `key.md`) to call `supabase.auth.signUp({ data: { tenant_id:
-- '<any tenant>' } })` directly, which let a stranger join ANY existing
-- company with no invitation at all.
--
-- admin-create-user has been updated in the same change to stop relying on
-- this metadata path — it now sets tenant_id via a direct service-role
-- upsert on public.users right after creating the auth user (see the
-- existing `.from('users').upsert(...)` call in that function), which was
-- already happening and is unaffected by this migration.
--
-- Any signup without `new_company_name` now always defaults to the single
-- fallback tenant, exactly like signups behaved before per-tenant metadata
-- was introduced.

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
