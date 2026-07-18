alter table contract_types add column if not exists terms jsonb default '[]'::jsonb;
alter table contracts add column if not exists terms jsonb default '[]'::jsonb;

-- Adjust contracts table structure to match application expectations
alter table contracts add column if not exists contract_user_name text;
alter table contracts add column if not exists contract_user_phone text;
alter table contracts add column if not exists contract_user_password_hash text;

-- Drop the view first to avoid column mismatch errors
drop view if exists contracts_view;

create or replace view contracts_view as
select 
  c.id,
  c.client_id,
  c.block_id,
  -- c.zone_id omitted to avoid duplicate column name with the calculated field
  c.code,
  c.contract_type_id,
  c.status,
  c.duration_months,
  c.address_details,
  c.contract_user_name,
  c.contract_user_phone,
  c.contract_user_password_hash,
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
from contracts c
left join blocks b on b.id = c.block_id
left join zones z on z.id = coalesce(c.zone_id, b.zone_id)
where c.deleted_at is null;
