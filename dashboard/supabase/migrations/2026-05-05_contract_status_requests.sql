-- Contract status approval workflow.

create table if not exists public.contract_status_requests (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.contracts(id) on delete cascade,
  supervisor_id uuid not null references public.users(id) on delete cascade,
  current_status text not null,
  requested_status text not null check (requested_status in ('active', 'pending', 'expired', 'cancelled', 'terminated')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_notes text,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.contract_status_requests
  drop constraint if exists contract_status_requests_supervisor_id_fkey;
alter table public.contract_status_requests
  add constraint contract_status_requests_supervisor_id_fkey
  foreign key (supervisor_id) references public.users(id) on delete cascade;

alter table public.contract_status_requests
  drop constraint if exists contract_status_requests_reviewed_by_fkey;
alter table public.contract_status_requests
  add constraint contract_status_requests_reviewed_by_fkey
  foreign key (reviewed_by) references public.users(id) on delete set null;

create index if not exists idx_contract_status_requests_status on public.contract_status_requests(status);
create index if not exists idx_contract_status_requests_contract_id on public.contract_status_requests(contract_id);
create index if not exists idx_contract_status_requests_supervisor_id on public.contract_status_requests(supervisor_id);
create index if not exists idx_contract_status_requests_created_at on public.contract_status_requests(created_at desc);

drop trigger if exists set_contract_status_requests_updated_at on public.contract_status_requests;
create trigger set_contract_status_requests_updated_at
before update on public.contract_status_requests
for each row execute function public.set_updated_at();

alter table public.contract_status_requests enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update on table public.contract_status_requests to authenticated;
grant all on table public.contract_status_requests to service_role;

drop policy if exists "Supervisors can create contract status requests" on public.contract_status_requests;
create policy "Supervisors can create contract status requests"
  on public.contract_status_requests
  for insert
  with check (supervisor_id = auth.uid());

drop policy if exists "Supervisors can view their contract status requests" on public.contract_status_requests;
create policy "Supervisors can view their contract status requests"
  on public.contract_status_requests
  for select
  using (supervisor_id = auth.uid() or public.is_admin());

drop policy if exists "Admins manage contract status requests" on public.contract_status_requests;
create policy "Admins manage contract status requests"
  on public.contract_status_requests
  for all
  using (public.is_admin())
  with check (public.is_admin());
-- Notifications table (simple schema for dashboard notifications)
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  title text not null,
  body text,
  "read" boolean not null default false,
  meta jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_id on public.notifications(user_id);
create index if not exists idx_notifications_created_at on public.notifications(created_at desc);

alter table public.notifications enable row level security;

grant select, insert, update on table public.notifications to authenticated;
grant all on table public.notifications to service_role;

drop policy if exists "Authenticated read notifications" on public.notifications;
create policy "Authenticated read notifications"
  on public.notifications
  for select
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Authenticated insert notifications" on public.notifications;
create policy "Authenticated insert notifications"
  on public.notifications
  for insert
  with check (user_id is null or user_id = auth.uid() or public.is_admin());

drop policy if exists "Authenticated update notifications" on public.notifications;
create policy "Authenticated update notifications"
  on public.notifications
  for update
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());


create or replace function public.create_contract_status_request(
  p_contract_id uuid,
  p_requested_status text
)
returns public.contract_status_requests
language plpgsql
as $$
declare
  v_user_id uuid := auth.uid();
  v_supervisor_name text;
  v_contract public.contracts_view%rowtype;
  v_request public.contract_status_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_requested_status not in ('active', 'pending', 'expired', 'cancelled', 'terminated') then
    raise exception 'Invalid requested status';
  end if;

  select * into v_contract
  from public.contracts_view
  where id = p_contract_id;

  if not found then
    raise exception 'Contract not found';
  end if;

  if p_requested_status = v_contract.status then
    raise exception 'Requested status matches current status';
  end if;

  if exists (
    select 1
    from public.contract_status_requests r
    where r.contract_id = p_contract_id
      and r.supervisor_id = v_user_id
      and r.status = 'pending'
  ) then
    raise exception 'A pending request already exists for this contract';
  end if;

  select coalesce(full_name, email, v_user_id::text)
  into v_supervisor_name
  from public.users
  where id = v_user_id;

  insert into public.contract_status_requests (
    contract_id,
    supervisor_id,
    current_status,
    requested_status
  )
  values (
    p_contract_id,
    v_user_id,
    v_contract.status,
    p_requested_status
  )
  returning * into v_request;

  -- Create a broadcast notification for admins to review this request
  insert into public.notifications (user_id, title, body, meta)
  values (
    null,
    format('طلب تغيير حالة للعقد %s', coalesce(v_contract.code::text, p_contract_id::text)),
    format('%s طلب تغيير حالة العقد %s من %s إلى %s', 
      coalesce(v_supervisor_name, v_user_id::text), 
      coalesce(v_contract.code::text, p_contract_id::text), 
      case v_request.current_status
        when 'active' then 'نشط'
        when 'pending' then 'قيد الانتظار'
        when 'expired' then 'منتهي'
        when 'terminated' then 'ملغي'
        when 'cancelled' then 'ملغي'
        else v_request.current_status
      end, 
      case v_request.requested_status
        when 'active' then 'نشط'
        when 'pending' then 'قيد الانتظار'
        when 'expired' then 'منتهي'
        when 'terminated' then 'ملغي'
        when 'cancelled' then 'ملغي'
        else v_request.requested_status
      end
    ),
    json_build_object('contract_id', v_request.contract_id, 'request_id', v_request.id)::jsonb
  );

  return v_request;
end;
$$;

create or replace function public.review_contract_status_request(
  p_request_id uuid,
  p_decision text,
  p_admin_notes text default null
)
returns public.contract_status_requests
language plpgsql
as $$
declare
  v_request public.contract_status_requests;
  v_contract_code text;
begin
  if not public.is_admin() then
    raise exception 'Admins only';
  end if;

  select * into v_request
  from public.contract_status_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'Request has already been reviewed';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'Invalid decision';
  end if;

  update public.contract_status_requests
  set
    status = p_decision,
    admin_notes = coalesce(p_admin_notes, admin_notes),
    reviewed_by = auth.uid(),
    reviewed_at = now()
  where id = p_request_id
  returning * into v_request;

  if p_decision = 'approved' then
    update public.contracts
    set status = v_request.requested_status
    where id = v_request.contract_id;
  end if;

  -- Notify the supervisor about the decision
  select code into v_contract_code
  from public.contracts
  where id = v_request.contract_id;

  insert into public.notifications (user_id, title, body, meta)
  values (
    v_request.supervisor_id,
    format('قرار بشأن طلب تغيير حالة العقد %s', coalesce(v_contract_code, v_request.contract_id::text)),
    format('تم %s طلبك لتغيير حالة العقد %s. ملاحظات: %s', 
      case p_decision
        when 'approved' then 'قبول'
        when 'rejected' then 'رفض'
        else p_decision
      end, 
      coalesce(v_contract_code, v_request.contract_id::text), 
      coalesce(p_admin_notes, '')
    ),
    json_build_object('request_id', v_request.id, 'contract_id', v_request.contract_id, 'decision', p_decision)::jsonb
  );

  return v_request;
end;
$$;

grant execute on function public.create_contract_status_request(uuid, text) to authenticated;
grant execute on function public.review_contract_status_request(uuid, text, text) to authenticated;
grant execute on function public.create_contract_status_request(uuid, text) to service_role;
grant execute on function public.review_contract_status_request(uuid, text, text) to service_role;