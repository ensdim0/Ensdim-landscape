-- Contact requests management for admin dashboard.
-- Supports anonymous inserts from the public/mobile lead-request flow
-- and admin review/update/delete from the dashboard.

create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text not null,
  email text,
  notes text,
  source text not null default 'mobile_app',
  status text not null default 'new' check (status in ('new', 'contacted', 'in_progress', 'converted', 'closed')),
  admin_notes text,
  contacted_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_contact_requests_status on public.contact_requests(status);
create index if not exists idx_contact_requests_created_at on public.contact_requests(created_at desc);
create index if not exists idx_contact_requests_phone on public.contact_requests(phone);
create index if not exists idx_contact_requests_full_name on public.contact_requests(full_name);

drop trigger if exists set_contact_requests_updated_at on public.contact_requests;
create trigger set_contact_requests_updated_at
before update on public.contact_requests
for each row execute function public.set_updated_at();

alter table public.contact_requests enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant insert on table public.contact_requests to anon, authenticated;
grant select, update, delete on table public.contact_requests to authenticated;
grant all on table public.contact_requests to service_role;

drop policy if exists "Public can create contact requests" on public.contact_requests;
create policy "Public can create contact requests"
  on public.contact_requests
  for insert
  with check (true);

drop policy if exists "Admins manage contact requests" on public.contact_requests;
create policy "Admins manage contact requests"
  on public.contact_requests
  for all
  using (public.is_admin())
  with check (public.is_admin());