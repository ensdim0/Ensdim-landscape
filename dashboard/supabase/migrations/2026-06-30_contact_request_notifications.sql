-- Notify admins in dashboard when a new contact request (lead) is submitted from the mobile app.

create or replace function public.notify_contact_request_to_admins()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_phone text;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  v_name := coalesce(nullif(trim(new.full_name), ''), 'عميل محتمل');
  v_phone := coalesce(nullif(trim(new.phone), ''), '');

  insert into public.notifications (user_id, title, body, meta)
  select
    ur.user_id,
    'طلب عميل جديد',
    v_name || ' سجل طلب تواصل جديد' ||
      case when v_phone <> '' then ' — ' || v_phone else '' end,
    jsonb_build_object(
      'type', 'contact_request',
      'request_id', new.id,
      'full_name', v_name,
      'phone', v_phone
    )
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where r.name = 'admin';

  return new;
end;
$$;

drop trigger if exists trg_notify_contact_request_to_admins on public.contact_requests;
create trigger trg_notify_contact_request_to_admins
after insert on public.contact_requests
for each row execute function public.notify_contact_request_to_admins();
