-- ============================================================================
-- Migration: Remove clients table, link contracts directly to users (profiles)
-- Date: 2026-02-15
-- Purpose: Contracts now reference users.id (role='client') instead of clients.id
-- ============================================================================

-- 1. Drop dependent RLS policies FIRST
-- ──────────────────────────────────────
drop policy if exists "Admins full access comments" on public.client_comments;
drop policy if exists "Clients create comments" on public.client_comments;
drop policy if exists "Clients read own comments" on public.client_comments;
drop policy if exists "Admins full access clients" on public.clients;
drop policy if exists "Clients read own data" on public.clients;
drop policy if exists "Clients read own contracts" on public.contracts;
drop policy if exists "Clients read own invoices" on public.invoices;

-- 2. Add new user_id column to contracts (to replace client_id)
-- ──────────────────────────────────────
alter table public.contracts
  add column if not exists user_id uuid references public.users(id) on delete restrict;

-- 3. Migrate data: copy client_id → user_id by looking up clients.user_id
-- ──────────────────────────────────────
update public.contracts c
set user_id = cl.user_id
from public.clients cl
where c.client_id = cl.id
  and cl.user_id is not null;

-- 4. Drop client_comments table (depends on clients)
-- ──────────────────────────────────────
drop table if exists public.client_comments cascade;

-- 5. Drop contracts_view BEFORE dropping client_id (view depends on it)
-- ──────────────────────────────────────
drop view if exists public.contracts_view cascade;

-- 6. Drop the old client_id FK from contracts
-- ──────────────────────────────────────
alter table public.contracts drop constraint if exists contracts_client_id_fkey;
alter table public.contracts drop column if exists client_id;

-- 7. Drop the clients table
-- ──────────────────────────────────────
drop table if exists public.clients cascade;

-- 8. Recreate contracts_view using user_id → users
-- ──────────────────────────────────────

create or replace view public.contracts_view as
select 
  c.id,
  c.user_id,
  c.block_id,
  c.code,
  c.contract_type_id,
  c.status,
  c.duration_months,
  c.address_details,
  c.start_date,
  c.end_date,
  c.total_value,
  c.terms,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  coalesce(c.zone_id, b.zone_id) as zone_id,
  z.line_id,
  u.full_name as client_name,
  u.email as client_email
from public.contracts c
left join public.blocks b on b.id = c.block_id
left join public.zones z on z.id = coalesce(c.zone_id, b.zone_id)
left join public.users u on u.id = c.user_id
where c.deleted_at is null;

-- 8. Grant access to new view
-- ──────────────────────────────────────
grant select on public.contracts_view to authenticated;

-- 9. Recreate RLS policies for contracts (now using user_id directly)
-- ──────────────────────────────────────
drop policy if exists "Clients read own contracts" on public.contracts;
create policy "Clients read own contracts" on public.contracts
  for select using (user_id = auth.uid());

drop policy if exists "Clients read own invoices" on public.invoices;
create policy "Clients read own invoices" on public.invoices
  for select using (
    exists (
      select 1 from public.contracts ct 
      where ct.id = invoices.contract_id 
        and ct.user_id = auth.uid()
    )
  );

-- Done! contracts now reference users.id directly
-- Only users with role='client' should be assignable (enforced at application level)
