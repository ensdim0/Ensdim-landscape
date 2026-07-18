-- Notify admins in dashboard when a client adds a comment on a visit.

create or replace function public.notify_client_comment_to_admins()
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
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  v_author := coalesce(nullif(trim(new.author_name), ''), 'العميل');

  select c.code
  into v_contract_code
  from public.contracts c
  where c.id = new.contract_id;

  select v.title, v.notes, v.visit_date
  into v_visit_title, v_visit_notes, v_visit_date
  from public.visits v
  where v.id = new.visit_id;

  v_visit_label := coalesce(
    nullif(trim(v_visit_title), ''),
    nullif(trim(v_visit_notes), ''),
    case when v_visit_date is not null then to_char(v_visit_date, 'YYYY-MM-DD') end,
    'الزيارة'
  );

  insert into public.notifications (user_id, title, body, meta)
  select
    ur.user_id,
    'تعليق عميل جديد',
    v_author || ' أضاف تعليقًا على ' || v_visit_label ||
      case
        when v_contract_code is not null then ' (عقد ' || v_contract_code || ')'
        else ''
      end,
    jsonb_build_object(
      'type', 'client_comment',
      'contract_id', new.contract_id,
      'visit_id', new.visit_id,
      'comment_id', new.id,
      'author_name', v_author
    )
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where r.name = 'admin';

  return new;
end;
$$;

drop trigger if exists trg_notify_client_comment_to_admins on public.client_comments;
create trigger trg_notify_client_comment_to_admins
after insert on public.client_comments
for each row execute function public.notify_client_comment_to_admins();
