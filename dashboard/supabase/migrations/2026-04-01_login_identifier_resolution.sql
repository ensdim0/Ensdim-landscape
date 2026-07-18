-- Add phone support and resolve login identifiers to real auth emails.
-- This script is safe even if public.users does not exist yet.

create table if not exists public.users (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null default 'User',
  email text not null,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.users add column if not exists phone text;

insert into public.users (id, email, phone, full_name)
select
  au.id,
  au.email,
  coalesce(au.raw_user_meta_data->>'phone', null),
  coalesce(au.raw_user_meta_data->>'fullName', au.raw_user_meta_data->>'full_name', 'User')
from auth.users au
on conflict (id) do update
set
  email = excluded.email,
  phone = coalesce(public.users.phone, excluded.phone),
  full_name = case
    when public.users.full_name is null or btrim(public.users.full_name) = '' then excluded.full_name
    else public.users.full_name
  end;

update public.users
set phone = regexp_replace(split_part(email, '@', 1), '[^0-9+]', '', 'g')
where phone is null
  and email ilike '%@bostan.local';

create or replace function public.resolve_login_email(login_identifier text)
returns text
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  cleaned_identifier text;
  normalized_phone text;
  resolved_email text;
begin
  cleaned_identifier := lower(trim(login_identifier));

  if cleaned_identifier is null or cleaned_identifier = '' then
    return null;
  end if;

  if cleaned_identifier like '%@%' then
    return cleaned_identifier;
  end if;

  normalized_phone := regexp_replace(cleaned_identifier, '[^0-9+]', '', 'g');
  if normalized_phone = '' then
    return null;
  end if;

  -- Preferred source: public.users.phone
  select u.email into resolved_email
  from public.users u
  where regexp_replace(coalesce(u.phone, ''), '[^0-9+]', '', 'g') = normalized_phone
  order by u.created_at desc nulls last
  limit 1;

  if resolved_email is not null then
    return resolved_email;
  end if;

  -- Legacy source: auth email stored as phone@bostan.local
  select au.email into resolved_email
  from auth.users au
  where lower(au.email) = normalized_phone || '@bostan.local'
  limit 1;

  if resolved_email is not null then
    return resolved_email;
  end if;

  -- Optional source: phone in auth metadata
  select au.email into resolved_email
  from auth.users au
  where regexp_replace(coalesce(au.raw_user_meta_data->>'phone', ''), '[^0-9+]', '', 'g') = normalized_phone
  limit 1;

  return resolved_email;
end;
$$;

grant execute on function public.resolve_login_email(text) to anon, authenticated;