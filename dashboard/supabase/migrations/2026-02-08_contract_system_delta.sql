create table if not exists contract_types (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table if exists contracts
  add column if not exists contract_type_id uuid references contract_types(id) on delete set null,
  add column if not exists duration_months integer not null default 12,
  add column if not exists anchor_lat numeric(10,7),
  add column if not exists anchor_lng numeric(10,7),
  add column if not exists address_line text,
  add column if not exists address_street text,
  add column if not exists address_avenue text,
  add column if not exists address_house text;

alter table if exists assets
  add column if not exists asset_type text,
  add column if not exists quantity integer not null default 1,
  add column if not exists size_class text;

create table if not exists contract_tasks (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references contracts(id) on delete cascade,
  title text not null,
  month integer not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists visits (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references contracts(id) on delete cascade,
  supervisor_id uuid references supervisors(id) on delete restrict,
  visit_date timestamptz not null,
  gps_lat numeric(10,7),
  gps_lng numeric(10,7),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists task_executions (
  id uuid primary key default uuid_generate_v4(),
  task_id uuid references contract_tasks(id) on delete cascade,
  supervisor_id uuid references supervisors(id) on delete restrict,
  visit_id uuid references visits(id) on delete set null,
  notes text,
  status text not null default 'completed',
  gps_lat numeric(10,7),
  gps_lng numeric(10,7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists task_photos (
  id uuid primary key default uuid_generate_v4(),
  execution_id uuid references task_executions(id) on delete cascade,
  photo_path text not null,
  photo_type text not null default 'before',
  created_at timestamptz not null default now()
);

create table if not exists client_comments (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references contracts(id) on delete cascade,
  client_id uuid references clients(id) on delete restrict,
  comment text not null,
  attachment_path text,
  created_at timestamptz not null default now()
);

create index if not exists idx_contracts_type on contracts(contract_type_id);
create index if not exists idx_tasks_contract on contract_tasks(contract_id);
create index if not exists idx_tasks_month on contract_tasks(month);
create index if not exists idx_executions_task on task_executions(task_id);
create index if not exists idx_photos_execution on task_photos(execution_id);
create index if not exists idx_comments_contract on client_comments(contract_id);

create index if not exists idx_visits_contract on visits(contract_id);
create index if not exists idx_visits_supervisor on visits(supervisor_id);

drop trigger if exists trg_contract_types_updated on contract_types;
create trigger trg_contract_types_updated before update on contract_types
for each row execute function set_updated_at();

drop trigger if exists trg_contract_tasks_updated on contract_tasks;
create trigger trg_contract_tasks_updated before update on contract_tasks
for each row execute function set_updated_at();

drop trigger if exists trg_task_executions_updated on task_executions;
create trigger trg_task_executions_updated before update on task_executions
for each row execute function set_updated_at();
