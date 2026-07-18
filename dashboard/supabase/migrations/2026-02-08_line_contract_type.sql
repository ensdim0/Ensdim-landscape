alter table if exists geographic_lines
  add column if not exists contract_type_id uuid references contract_types(id) on delete set null;

create index if not exists idx_lines_contract_type on geographic_lines(contract_type_id);
