drop view if exists contracts_view;

create or replace view contracts_view as
select c.id,
  c.client_id,
  c.block_id,
  c.zone_id,
  c.code,
  c.contract_type_id,
  c.status,
  c.duration_months,
  c.anchor_lat,
  c.anchor_lng,
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
  z.line_id
from contracts c
left join blocks b on b.id = c.block_id
left join zones z on z.id = coalesce(c.zone_id, b.zone_id)
where c.deleted_at is null;