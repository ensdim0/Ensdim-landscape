-- Attach client feedback to specific visits and expose it safely to supervisors.

create table if not exists public.client_comments (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references public.contracts(id) on delete cascade,
  visit_id uuid references public.visits(id) on delete cascade,
  client_id uuid,
  author_user_id uuid references public.users(id) on delete set null,
  author_name text,
  comment text not null,
  attachment_path text,
  created_at timestamptz not null default now()
);

alter table if exists public.client_comments
  add column if not exists visit_id uuid references public.visits(id) on delete cascade,
  add column if not exists author_user_id uuid references public.users(id) on delete set null,
  add column if not exists author_name text;

create index if not exists idx_client_comments_contract_id
  on public.client_comments(contract_id);

create index if not exists idx_client_comments_visit_id
  on public.client_comments(visit_id);

alter table public.client_comments enable row level security;

grant usage on schema public to authenticated;
grant select, insert on table public.client_comments to authenticated;
grant all on table public.client_comments to service_role;

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

drop policy if exists "Admins full access comments" on public.client_comments;
create policy "Admins full access comments"
  on public.client_comments
  for all
  using (public.is_admin());

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

drop policy if exists "Supervisors read assigned visit comments" on public.client_comments;
create policy "Supervisors read assigned visit comments"
  on public.client_comments
  for select
  using (
    client_comments.visit_id is not null
    and exists (
      select 1
      from public.visits v
      join public.contracts c on c.id = v.contract_id
      join public.zones z on z.id = c.zone_id
      join public.users u on u.assigned_line_id = z.line_id
      where v.id = client_comments.visit_id
        and u.id = auth.uid()
    )
  );
