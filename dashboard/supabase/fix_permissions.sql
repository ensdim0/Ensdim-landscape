-- Run this script in the Supabase SQL Editor to force your user to be an Admin
-- This fixes the "401 Unauthorized" error when creating clients.

do $$
declare
  user_rec record;
  admin_role_id uuid;
begin
  -- Get the admin role id
  select id into admin_role_id from public.roles where name = 'admin';

  if admin_role_id is not null then
      -- Loop through all users in auth.users
      for user_rec in select id, email, raw_user_meta_data from auth.users loop
        
        -- 1. Ensure user is in public.users
        insert into public.users (id, email, full_name)
        values (
            user_rec.id, 
            user_rec.email, 
            coalesce(user_rec.raw_user_meta_data->>'fullName', 'Dev User')
        )
        on conflict (id) do nothing;

        -- 2. Assign admin role
        insert into public.user_roles (user_id, role_id)
        values (user_rec.id, admin_role_id)
        on conflict (user_id, role_id) do nothing;
        
      end loop;
  end if;
end;
$$;