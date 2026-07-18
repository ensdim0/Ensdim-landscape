-- Notify admins and contract owner when a supervisor adds a note on a visit/contract.

create or replace function public.notify_supervisor_note_to_admins()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author text;
  v_contract_code text;
  v_visit_title text;
  v_visit_notes text;
  v_visit_date date;
  v_visit_label text;
  v_contract_user uuid;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  select coalesce(nullif(trim(u.full_name), ''), u.email, 'المشرف') into v_author
  from public.users u
  where u.id = new.created_by;

  select c.code, c.user_id into v_contract_code, v_contract_user
  from public.contracts c
  where c.id = new.contract_id;

  select v.title, v.notes, v.visit_date into v_visit_title, v_visit_notes, v_visit_date
  from public.visits v
  where v.id = new.visit_id;

  v_visit_label := coalesce(
    nullif(trim(v_visit_title), ''),
    nullif(trim(v_visit_notes), ''),
    case when v_visit_date is not null then to_char(v_visit_date, 'YYYY-MM-DD') end,
    'الزيارة'
  );

  -- Notify all admins
  insert into public.notifications (user_id, title, body, meta)
  select
    ur.user_id,
    'تمت إضافة ملاحظة من المشرف',
    'أضاف ' || coalesce(v_author, 'المشرف') || ' ملاحظة على ' || v_visit_label ||
      case when v_contract_code is not null then ' في العقد ' || v_contract_code else '' end || '.',
    jsonb_build_object(
      'type', 'supervisor_note',
      'contract_id', new.contract_id,
      'visit_id', new.visit_id,
      'note_id', new.id,
      'author_name', coalesce(v_author, 'المشرف'),
      'visibility', new.visibility
    )
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where r.name = 'admin';

  -- If note is visible to client, notify contract owner
  if new.visibility = 'all' and v_contract_user is not null then
    insert into public.notifications (user_id, title, body, meta)
    values (
      v_contract_user,
      'تمت إضافة ملاحظة على عقدك',
      'أضاف ' || coalesce(v_author, 'المشرف') || ' ملاحظة على ' || v_visit_label || '.',
      jsonb_build_object(
        'type', 'supervisor_note',
        'contract_id', new.contract_id,
        'visit_id', new.visit_id,
        'note_id', new.id,
        'author_name', coalesce(v_author, 'المشرف'),
        'visibility', new.visibility
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_supervisor_note_to_admins on public.supervisor_notes;
create trigger trg_notify_supervisor_note_to_admins
after insert on public.supervisor_notes
for each row execute function public.notify_supervisor_note_to_admins();

grant execute on function public.notify_supervisor_note_to_admins() to authenticated;
grant execute on function public.notify_supervisor_note_to_admins() to service_role;
