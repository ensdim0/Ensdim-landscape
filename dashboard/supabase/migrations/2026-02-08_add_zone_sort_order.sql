alter table if exists zones
  add column if not exists sort_order integer not null default 0;

create index if not exists idx_zones_line_order on zones(line_id, sort_order);
