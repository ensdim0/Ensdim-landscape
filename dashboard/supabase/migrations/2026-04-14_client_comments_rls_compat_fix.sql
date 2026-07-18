-- Fix 42501 on client_comments inserts by making ownership checks schema-compatible.

create or replace function public.can_current_user_comment_contract(p_contract_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  allowed boolean := false;
begin
  if auth.uid() is null or p_contract_id is null then
    return false;
  end if;

  -- Newer schema path: contracts.user_id -> auth.uid()
  begin
    execute
      'select exists (select 1 from public.contracts c where c.id = $1 and c.user_id = auth.uid())'
      into allowed
      using p_contract_id;
    if allowed then
      return true;
    end if;
  exception
    when undefined_column then
      null;
  end;

  -- Legacy schema path: contracts.client_id -> clients.user_id -> auth.uid()
  begin
    execute
      'select exists (
         select 1
         from public.contracts ct
         join public.clients cl on cl.id = ct.client_id
         where ct.id = $1
           and cl.user_id = auth.uid()
       )'
      into allowed
      using p_contract_id;
    if allowed then
      return true;
    end if;
  exception
    when undefined_table or undefined_column then
      null;
  end;

  return false;
end;
$$;

grant execute on function public.can_current_user_comment_contract(uuid) to authenticated;

alter table if exists public.client_comments enable row level security;

grant usage on schema public to authenticated;
grant select, insert on table public.client_comments to authenticated;
grant all on table public.client_comments to service_role;

drop policy if exists "Clients create comments" on public.client_comments;
create policy "Clients create comments"
  on public.client_comments
  for insert
  with check (public.can_current_user_comment_contract(client_comments.contract_id));

drop policy if exists "Clients read own comments" on public.client_comments;
create policy "Clients read own comments"
  on public.client_comments
  for select
  using (public.can_current_user_comment_contract(client_comments.contract_id));
