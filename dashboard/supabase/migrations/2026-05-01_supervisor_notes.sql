-- Supervisor notes with visibility control (supervisors only or supervisors + clients)

create table if not exists public.supervisor_notes (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  contract_id uuid not null references public.contracts(id) on delete cascade,
  content text not null,
  visibility text not null default 'supervisors_only' check (visibility in ('supervisors_only', 'all')),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_supervisor_notes_visit_id on public.supervisor_notes(visit_id);
create index if not exists idx_supervisor_notes_contract_id on public.supervisor_notes(contract_id);
create index if not exists idx_supervisor_notes_created_by on public.supervisor_notes(created_by);

alter table public.supervisor_notes enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.supervisor_notes to authenticated;
grant all on table public.supervisor_notes to service_role;

-- Supervisors and admins can see and manage notes
drop policy if exists "Supervisors manage supervisor notes" on public.supervisor_notes;
drop policy if exists "Supervisors and admins manage supervisor notes" on public.supervisor_notes;
create policy "Supervisors and admins manage supervisor notes"
  on public.supervisor_notes
  for all
  using (
    public.is_admin()
    or exists (
      select 1
      from public.visits v
      join public.contracts c on c.id = v.contract_id
      join public.zones z on z.id = c.zone_id
      join public.users u on u.assigned_line_id = z.line_id
      where v.id = supervisor_notes.visit_id
        and u.id = auth.uid()
    )
  )
  with check (
    public.is_admin()
    or exists (
      select 1
      from public.visits v
      join public.contracts c on c.id = v.contract_id
      join public.zones z on z.id = c.zone_id
      join public.users u on u.assigned_line_id = z.line_id
      where v.id = supervisor_notes.visit_id
        and u.id = auth.uid()
    )
  );

-- Clients can see notes with visibility = 'all'
drop policy if exists "Clients read visible supervisor notes" on public.supervisor_notes;
create policy "Clients read visible supervisor notes"
  on public.supervisor_notes
  for select
  using (
    visibility = 'all'
    and exists (
      select 1
      from public.contracts c
      where c.id = supervisor_notes.contract_id
        and c.user_id = auth.uid()
    )
  );
