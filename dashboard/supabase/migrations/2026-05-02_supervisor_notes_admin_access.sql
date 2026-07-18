-- Fix supervisor notes permissions: allow authenticated delete and admin CRUD access.

grant select, insert, update, delete on table public.supervisor_notes to authenticated;

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