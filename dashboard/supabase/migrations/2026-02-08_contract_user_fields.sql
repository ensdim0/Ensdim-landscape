alter table contracts
  add column if not exists contract_user_name text,
  add column if not exists contract_user_phone text,
  add column if not exists contract_user_password_hash text;
