alter table if exists contracts
  drop column if exists vehicle_number,
  drop column if exists custody_phone,
  drop column if exists custody_reference;

alter table if exists geographic_lines
  add column if not exists vehicle_number text,
  add column if not exists custody_phone text,
  add column if not exists custody_reference text;
