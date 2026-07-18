insert into roles (name) values
  ('admin'),
  ('supervisor'),
  ('client')
  on conflict do nothing;
