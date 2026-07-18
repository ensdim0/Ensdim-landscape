-- Notify admins when a supervisor completes a visit.

create or replace function public.notify_visit_completed_to_admins()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract_code text;
  v_supervisor_name text;
  v_completed_at timestamptz;
  v_summary text;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new.status <> 'completed' or old.status = 'completed' then
    return new;
  end if;

  select c.code
  into v_contract_code
  from public.contracts c
  where c.id = new.contract_id;

  select coalesce(u.full_name, u.email, 'المشرف')
  into v_supervisor_name
  from public.task_executions te
  left join public.users u on u.id = te.supervisor_id
  where te.visit_id = new.id
  order by te.created_at desc
  limit 1;

  v_completed_at := coalesce(new.completed_at, now());
  v_summary := nullif(trim(coalesce(new.summary, '')), '');

  insert into public.notifications (user_id, title, body, meta)
  select
    ur.user_id,
    'تم إنهاء زيارة',
    coalesce(v_supervisor_name, 'المشرف') ||
      ' أنهى زيارة العقد ' || coalesce(v_contract_code, '') ||
      ' بتاريخ ' || to_char(new.visit_date, 'YYYY-MM-DD') ||
      case when v_summary is not null then ' - ملخص: ' || left(v_summary, 140) else '' end,
    jsonb_build_object(
      'type', 'visit_completed',
      'contract_id', new.contract_id,
      'visit_id', new.id,
      'visit_date', new.visit_date,
      'completed_at', v_completed_at,
      'summary', coalesce(new.summary, ''),
      'supervisor_name', coalesce(v_supervisor_name, 'المشرف'),
      'contract_code', coalesce(v_contract_code, '')
    )
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where r.name = 'admin';

  return new;
end;
$$;

drop trigger if exists trg_notify_visit_completed_to_admins on public.visits;
create trigger trg_notify_visit_completed_to_admins
after update on public.visits
for each row execute function public.notify_visit_completed_to_admins();
