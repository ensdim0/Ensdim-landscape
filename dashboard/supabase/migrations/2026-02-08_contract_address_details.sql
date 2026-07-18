drop view if exists contracts_view;

alter table if exists contracts
  add column if not exists address_details text;

alter table if exists contracts
  drop column if exists address_line,
  drop column if exists address_street,
  drop column if exists address_avenue,
  drop column if exists address_house;

create or replace view contracts_view as
select c.*,
  b.zone_id,
  z.line_id
from contracts c
left join blocks b on b.id = c.block_id
left join zones z on z.id = b.zone_id
where c.deleted_at is null;
