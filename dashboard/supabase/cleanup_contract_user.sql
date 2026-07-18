-- Drop Contract User fields from contracts table
-- Since we are switching to Client Login only

-- Drop the view first because it depends on these columns
DROP VIEW IF EXISTS public.contracts_view;

-- Drop columns
ALTER TABLE public.contracts
DROP COLUMN IF EXISTS contract_user_name,
DROP COLUMN IF EXISTS contract_user_phone,
DROP COLUMN IF EXISTS contract_user_password_hash;

-- Recreate the view without these columns
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
  c.start_date,
  c.end_date,
  c.total_value,
  c.pdf_path,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  c.terms,
  coalesce(c.zone_id, b.zone_id) as zone_id,
  z.line_id
from public.contracts c
left join public.blocks b on b.id = c.block_id
left join public.zones z on z.id = coalesce(c.zone_id, b.zone_id)
where c.deleted_at is null;

-- Grant permissions again just in case
grant select on public.contracts_view to authenticated;
