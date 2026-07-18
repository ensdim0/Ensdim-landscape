-- Enable necessary extensions
create extension if not exists "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. Tables Definition (Correct Dependency Order)
-- -----------------------------------------------------------------------------

-- Roles
create table if not exists public.roles (
  id uuid primary key default uuid_generate_v4(),
  name text unique not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Users (Extends auth.users)
create table if not exists public.users (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  email text not null,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.users add column if not exists deleted_at timestamptz;
alter table public.users add column if not exists phone text;

-- User Roles
create table if not exists public.user_roles (
  user_id uuid references public.users(id) on delete cascade,
  role_id uuid references public.roles(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (user_id, role_id)
);

-- Contract Types
create table if not exists public.contract_types (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  description text,
  terms jsonb default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Geographic Lines
create table if not exists public.geographic_lines (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  line_type text not null,
  contract_type_id uuid references public.contract_types(id) on delete set null,
  is_active boolean not null default true,
  description text,
  vehicle_number text,
  custody_phone text,
  custody_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Zones
create table if not exists public.zones (
  id uuid primary key default uuid_generate_v4(),
  line_id uuid references public.geographic_lines(id) on delete restrict,
  name text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Blocks
create table if not exists public.blocks (
  id uuid primary key default uuid_generate_v4(),
  zone_id uuid references public.zones(id) on delete restrict,
  code text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (zone_id, code)
);

-- Clients
create table if not exists public.clients (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid unique references public.users(id) on delete set null,
  name text not null,
  phone text,
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Supervisors
create table if not exists public.supervisors (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid unique references public.users(id) on delete set null,
  full_name text not null,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Contracts
create table if not exists public.contracts (
  id uuid primary key default uuid_generate_v4(),
  client_id uuid references public.clients(id) on delete restrict,
  block_id uuid references public.blocks(id) on delete set null,
  zone_id uuid references public.zones(id) on delete set null,
  code text not null unique,
  contract_type_id uuid references public.contract_types(id) on delete set null,
  status text not null default 'draft',
  duration_months integer not null default 12,
  anchor_lat numeric(10,7),
  anchor_lng numeric(10,7),
  address_details text,
  contract_user_name text,
  contract_user_phone text,
  contract_user_password_hash text,
  start_date date not null,
  end_date date not null,
  total_value numeric(12,2) not null default 0,
  pdf_path text,
  terms jsonb default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.contracts add column if not exists deleted_at jsonb default '[]'::jsonb;
alter table public.contracts add column if not exists terms jsonb default '[]'::jsonb;

-- Ensure terms are jsonb (fix if previously created as text)
do $$
begin
  if exists (select 1 from information_schema.columns where table_name='contract_types' and column_name='terms' and data_type='text') then
    alter table public.contract_types alter column terms type jsonb using terms::jsonb;
  end if;
  if exists (select 1 from information_schema.columns where table_name='contracts' and column_name='terms' and data_type='text') then
    alter table public.contracts alter column terms type jsonb using terms::jsonb;
  end if;
end $$;

alter table public.contracts add column if not exists anchor_lat numeric(10,7);
alter table public.contracts add column if not exists anchor_lng numeric(10,7);
alter table public.contracts add column if not exists address_details text;
alter table public.contracts add column if not exists contract_user_name text;
alter table public.contracts add column if not exists contract_user_phone text;
alter table public.contracts add column if not exists contract_user_password_hash text;
alter table public.contracts add column if not exists pdf_path text;
alter table public.contracts add column if not exists updated_at timestamptz default now();

-- Assets
create table if not exists public.assets (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references public.contracts(id) on delete cascade,
  name text not null,
  serial_number text,
  asset_type text,
  quantity integer not null default 1,
  size_class text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Contract Tasks
create table if not exists public.contract_tasks (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references public.contracts(id) on delete cascade,
  title text not null,
  month integer not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Visits
create table if not exists public.visits (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references public.contracts(id) on delete cascade,
  supervisor_id uuid references public.supervisors(id) on delete restrict,
  visit_date timestamptz not null,
  gps_lat numeric(10,7),
  gps_lng numeric(10,7),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Task Executions
create table if not exists public.task_executions (
  id uuid primary key default uuid_generate_v4(),
  task_id uuid references public.contract_tasks(id) on delete cascade,
  supervisor_id uuid references public.supervisors(id) on delete restrict,
  visit_id uuid references public.visits(id) on delete set null,
  notes text,
  status text not null default 'completed',
  gps_lat numeric(10,7),
  gps_lng numeric(10,7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Task Photos
create table if not exists public.task_photos (
  id uuid primary key default uuid_generate_v4(),
  execution_id uuid references public.task_executions(id) on delete cascade,
  photo_path text not null,
  photo_type text not null default 'before',
  created_at timestamptz not null default now()
);

-- Client Comments
create table if not exists public.client_comments (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references public.contracts(id) on delete cascade,
  visit_id uuid references public.visits(id) on delete cascade,
  client_id uuid references public.clients(id) on delete restrict,
  author_user_id uuid references public.users(id) on delete set null,
  author_name text,
  comment text not null,
  attachment_path text,
  created_at timestamptz not null default now()
);

-- Assignments
create table if not exists public.assignments (
  id uuid primary key default uuid_generate_v4(),
  line_id uuid references public.geographic_lines(id) on delete cascade,
  supervisor_id uuid references public.supervisors(id) on delete restrict,
  start_date date not null,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Reports
create table if not exists public.reports (
  id uuid primary key default uuid_generate_v4(),
  visit_id uuid references public.visits(id) on delete cascade,
  summary text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Invoices
create table if not exists public.invoices (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references public.contracts(id) on delete cascade,
  amount numeric(12,2) not null,
  status text not null default 'issued',
  due_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.invoices add column if not exists deleted_at timestamptz;

-- Payments
create table if not exists public.payments (
  id uuid primary key default uuid_generate_v4(),
  invoice_id uuid references public.invoices(id) on delete cascade,
  amount numeric(12,2) not null,
  paid_at timestamptz not null default now(),
  method text not null,
  reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Audit Logs
create table if not exists public.audit_logs (
  id uuid primary key default uuid_generate_v4(),
  actor_id uuid references public.users(id) on delete set null,
  action text not null,
  entity text not null,
  entity_id uuid,
  payload jsonb,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- 2. Views
-- -----------------------------------------------------------------------------

-- Drop views first to avoid "cannot drop columns from view" errors during replacement
drop view if exists public.users_view cascade;
drop view if exists public.contracts_view cascade;
drop view if exists public.invoices_view cascade;

create or replace view public.users_view as
select u.id, u.full_name as "fullName", u.email, u.phone, r.name as role, u.created_at as "createdAt"
from public.users u
left join public.user_roles ur on ur.user_id = u.id
left join public.roles r on r.id = ur.role_id
where u.deleted_at is null;

create or replace view public.contracts_view as
select 
  c.id,
  c.client_id,
  c.block_id,
  c.code,
  c.contract_type_id,
  c.status,
  c.duration_months,
  c.anchor_lat,
  c.anchor_lng,
  c.address_details,
  c.contract_user_name,
  c.contract_user_phone,
  c.start_date,
  c.end_date,
  c.total_value,
  c.pdf_path,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  coalesce(c.zone_id, b.zone_id) as zone_id,
  z.line_id
from public.contracts c
left join public.blocks b on b.id = c.block_id
left join public.zones z on z.id = coalesce(c.zone_id, b.zone_id)
where c.deleted_at is null;

create or replace view public.invoices_view as
select i.*
from public.invoices i
where i.deleted_at is null;

-- -----------------------------------------------------------------------------
-- 3. Functions (Correct Order)
-- -----------------------------------------------------------------------------

-- Create a helper to check if user is admin (SECURITY DEFINER to bypass RLS recursion)
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 
    from public.user_roles ur
    join public.roles r on ur.role_id = r.id
    where ur.user_id = auth.uid()
    and r.name = 'admin'
  );
$$;

-- -----------------------------------------------------------------------------
-- 4. Triggers (timestamps & auth)
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply updated_at trigger for all tables that have updated_at
do $$
declare
  t text;
begin
  for t in 
    select c.table_name 
    from information_schema.columns c
    join information_schema.tables tbl on c.table_schema = tbl.table_schema and c.table_name = tbl.table_name
    where c.column_name = 'updated_at' 
    and c.table_schema = 'public'
    and tbl.table_type = 'BASE TABLE'
  loop
    execute format('drop trigger if exists trg_%I_updated on %I', t, t);
    execute format('create trigger trg_%I_updated before update on %I for each row execute function public.set_updated_at()', t, t);
  end loop;
end;
$$;

-- Auth Handler
create or replace function public.handle_new_user() 
returns trigger as $$
declare
  client_role_id uuid;
begin
  -- 1. Create user in public.users
  insert into public.users (id, email, phone, full_name)
  values (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'fullName', 'New User')
  );

  -- 2. Assign default role (client)
  select id into client_role_id from public.roles where name = 'client';
  
  if client_role_id is not null then
    insert into public.user_roles (user_id, role_id)
    values (new.id, client_role_id)
    on conflict do nothing;
  end if;

  return new;
end;
$$ language plpgsql security definer;

-- Recreate Auth Trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 5. Seed Data
-- -----------------------------------------------------------------------------

insert into public.roles (name) values
  ('admin'),
  ('supervisor'),
  ('client')
  on conflict (name) do nothing;

-- Backfill public.users from auth.users to ensure foreign keys work
insert into public.users (id, email, phone, full_name)
select id, email, raw_user_meta_data->>'phone', coalesce(raw_user_meta_data->>'fullName', 'User')
from auth.users
on conflict (id) do nothing;

create or replace function public.resolve_login_email(login_identifier text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select u.email
  from public.users u
  where lower(u.email) = lower(trim(login_identifier))
     or regexp_replace(coalesce(u.phone, ''), '[^0-9+]', '', 'g') = regexp_replace(coalesce(trim(login_identifier), ''), '[^0-9+]', '', 'g')
  order by case when lower(u.email) = lower(trim(login_identifier)) then 0 else 1 end
  limit 1;
$$;

grant execute on function public.resolve_login_email(text) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- 6. Privileges
-- -----------------------------------------------------------------------------

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on public.users_view to authenticated;
grant select on public.contracts_view to authenticated;
grant select on public.invoices_view to authenticated;

-- Ensure functions are executable
grant execute on function public.is_admin to authenticated;
grant execute on function public.is_admin to service_role;

-- -----------------------------------------------------------------------------
-- 7. RLS Policies
-- -----------------------------------------------------------------------------

-- Enable RLS on all tables
do $$
declare
  t text;
begin
  for t in select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE' loop
    execute format('alter table %I enable row level security', t);
  end loop;
end;
$$;

-- Roles
drop policy if exists "Read access for all" on public.roles;
create policy "Read access for all" on public.roles for select using (true);

-- User Roles
drop policy if exists "Read access for own role" on public.user_roles;
create policy "Read access for own role" on public.user_roles for select using (user_id = auth.uid());
drop policy if exists "Admins manage roles" on public.user_roles;
create policy "Admins manage roles" on public.user_roles for all using (public.is_admin());

-- Users
drop policy if exists "Read own profile" on public.users;
create policy "Read own profile" on public.users for select using (id = auth.uid());
drop policy if exists "Update own profile" on public.users;
create policy "Update own profile" on public.users for update using (id = auth.uid());
drop policy if exists "Admins manage users" on public.users;
create policy "Admins manage users" on public.users for all using (public.is_admin());

-- Geographic Lines
drop policy if exists "Admins full access lines" on public.geographic_lines;
create policy "Admins full access lines" on public.geographic_lines for all using ( public.is_admin() );
drop policy if exists "Authenticated read lines" on public.geographic_lines;
create policy "Authenticated read lines" on public.geographic_lines for select to authenticated using (true);

-- Zones
drop policy if exists "Admins full access zones" on public.zones;
create policy "Admins full access zones" on public.zones for all using ( public.is_admin() );
drop policy if exists "Authenticated read zones" on public.zones;
create policy "Authenticated read zones" on public.zones for select to authenticated using (true);

-- Blocks
drop policy if exists "Admins full access blocks" on public.blocks;
create policy "Admins full access blocks" on public.blocks for all using ( public.is_admin() );
drop policy if exists "Authenticated read blocks" on public.blocks;
create policy "Authenticated read blocks" on public.blocks for select to authenticated using (true);

-- Contract Types
drop policy if exists "Admins full access contract_types" on public.contract_types;
create policy "Admins full access contract_types" on public.contract_types for all using ( public.is_admin() );
drop policy if exists "Authenticated read contract_types" on public.contract_types;
create policy "Authenticated read contract_types" on public.contract_types for select to authenticated using (true);

-- Clients
drop policy if exists "Admins full access clients" on public.clients;
create policy "Admins full access clients" on public.clients for all using ( public.is_admin() );
drop policy if exists "Clients read own data" on public.clients;
create policy "Clients read own data" on public.clients for select using (user_id = auth.uid());

-- Contracts
drop policy if exists "Admins full access contracts" on public.contracts;
create policy "Admins full access contracts" on public.contracts for all using ( public.is_admin() );
drop policy if exists "Clients read own contracts" on public.contracts;
create policy "Clients read own contracts" on public.contracts for select using (
  exists (select 1 from public.clients c where c.id = contracts.client_id and c.user_id = auth.uid())
);

-- Contract Tasks
drop policy if exists "Admins full access tasks" on public.contract_tasks;
create policy "Admins full access tasks" on public.contract_tasks for all using ( public.is_admin() );

-- Visits
drop policy if exists "Admins full access visits" on public.visits;
create policy "Admins full access visits" on public.visits for all using ( public.is_admin() );
drop policy if exists "Supervisors read assigned visits" on public.visits;
create policy "Supervisors read assigned visits" on public.visits for select using (
    exists (select 1 from public.supervisors s where s.id = visits.supervisor_id and s.user_id = auth.uid())
);

-- Task Executions
drop policy if exists "Admins full access executions" on public.task_executions;
create policy "Admins full access executions" on public.task_executions for all using ( public.is_admin() );

-- Task Photos
drop policy if exists "Admins full access photos" on public.task_photos;
create policy "Admins full access photos" on public.task_photos for all using ( public.is_admin() );
drop policy if exists "Authenticated read photos" on public.task_photos;
create policy "Authenticated read photos" on public.task_photos for select to authenticated using (true);

-- Client Comments
drop policy if exists "Admins full access comments" on public.client_comments;
create policy "Admins full access comments" on public.client_comments for all using ( public.is_admin() );
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
drop policy if exists "Clients create comments" on public.client_comments;
create policy "Clients create comments" on public.client_comments for insert with check (
  public.can_current_user_comment_contract(client_comments.contract_id)
);
drop policy if exists "Clients read own comments" on public.client_comments;
create policy "Clients read own comments" on public.client_comments for select using (
  public.can_current_user_comment_contract(client_comments.contract_id)
);
drop policy if exists "Supervisors read assigned visit comments" on public.client_comments;
create policy "Supervisors read assigned visit comments" on public.client_comments for select using (
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

-- Invoices
drop policy if exists "Admins full access invoices" on public.invoices;
create policy "Admins full access invoices" on public.invoices for all using ( public.is_admin() );
drop policy if exists "Clients read own invoices" on public.invoices;
create policy "Clients read own invoices" on public.invoices for select using (
  exists (select 1 from public.contracts ct join public.clients cl on ct.client_id = cl.id where ct.id = invoices.contract_id and cl.user_id = auth.uid())      
);

-- -----------------------------------------------------------------------------
-- 8. Storage
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public) values ('task-photos', 'task-photos', false) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('attachments', 'attachments', true) on conflict do nothing;
update storage.buckets set public = false where id = 'task-photos';

drop policy if exists "Public Access to task photos" on storage.objects;
drop policy if exists "Authenticated read task photos" on storage.objects;
create policy "Authenticated read task photos" on storage.objects for select to authenticated using ( bucket_id = 'task-photos' );

drop policy if exists "Auth users upload task photos" on storage.objects;
create policy "Auth users upload task photos" on storage.objects for insert with check ( bucket_id = 'task-photos' and auth.role() = 'authenticated' );

-- -----------------------------------------------------------------------------
-- 9. Optional Dev Admin Bootstrap (Opt-In)
-- -----------------------------------------------------------------------------
-- To enable locally only: select set_config('app.enable_dev_admin_bootstrap', 'true', false);
do $$
declare
  enable_dev_admin_bootstrap boolean := coalesce(current_setting('app.enable_dev_admin_bootstrap', true), 'false') = 'true';
  user_rec record;
  admin_role_id uuid;
begin
  if not enable_dev_admin_bootstrap then
    raise notice 'Skipping dev admin bootstrap. Set app.enable_dev_admin_bootstrap=true to enable explicitly.';
    return;
  end if;

  -- Get the admin role id
  select id into admin_role_id from public.roles where name = 'admin';

  if admin_role_id is not null then
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
