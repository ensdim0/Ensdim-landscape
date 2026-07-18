-- Resolve login identifiers to the effective auth email.
-- Supports:
-- 1) contact email saved in public.users.email
-- 2) phone number in public.users.phone
-- 3) legacy phone@bostan.local auth emails
-- 4) phone stored in auth metadata

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
    -- If user entered contact email from public.users, map to auth.users.email.
    select coalesce(lower(au.email), lower(u.email)) into resolved_email
    from public.users u
    left join auth.users au on au.id = u.id
    where lower(coalesce(u.email, '')) = cleaned_identifier
    order by u.created_at desc nulls last
    limit 1;

    if resolved_email is not null and resolved_email <> '' then
      return resolved_email;
    end if;

    -- Fallback: treat as direct auth email.
    return cleaned_identifier;
  end if;

  normalized_phone := regexp_replace(cleaned_identifier, '[^0-9+]', '', 'g');
  if normalized_phone = '' then
    return null;
  end if;

  -- Preferred source: public.users.phone mapped to auth.users.email.
  select coalesce(lower(au.email), lower(u.email)) into resolved_email
  from public.users u
  left join auth.users au on au.id = u.id
  where regexp_replace(coalesce(u.phone, ''), '[^0-9+]', '', 'g') = normalized_phone
  order by u.created_at desc nulls last
  limit 1;

  if resolved_email is not null and resolved_email <> '' then
    return resolved_email;
  end if;

  -- Legacy source: auth email stored as phone@bostan.local
  select lower(au.email) into resolved_email
  from auth.users au
  where lower(au.email) = normalized_phone || '@bostan.local'
  limit 1;

  if resolved_email is not null and resolved_email <> '' then
    return resolved_email;
  end if;

  -- Optional source: phone in auth metadata
  select lower(au.email) into resolved_email
  from auth.users au
  where regexp_replace(coalesce(au.raw_user_meta_data->>'phone', ''), '[^0-9+]', '', 'g') = normalized_phone
  limit 1;

  return resolved_email;
end;
$$;

grant execute on function public.resolve_login_email(text) to anon, authenticated;
