-- Generate internal admin notifications for worker visa expiry.

create or replace function public.sync_worker_visa_expiry_notifications()
returns integer
language plpgsql
as $$
declare
  v_worker record;
  v_type text;
  v_title text;
  v_body text;
  v_days_left integer;
  v_exists boolean;
  v_inserted integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Admins only';
  end if;

  for v_worker in
    select id, name, visa_end
    from public.workers
    where visa_end <= current_date + 30
  loop
    v_days_left := (v_worker.visa_end - current_date);

    if v_days_left < 0 then
      v_type := 'worker_visa_expired';
      v_title := format('تأشيرة العامل %s منتهية', v_worker.name);
      v_body := format('تأشيرة العامل %s انتهت في %s', v_worker.name, to_char(v_worker.visa_end, 'YYYY-MM-DD'));
    else
      v_type := 'worker_visa_expiring';
      v_title := format('تأشيرة العامل %s تنتهي قريباً', v_worker.name);
      v_body := format('تأشيرة العامل %s تنتهي خلال %s يوم', v_worker.name, v_days_left);
    end if;

    select exists (
      select 1
      from public.notifications n
      where coalesce(n.meta->>'type', '') = v_type
        and coalesce(n.meta->>'worker_id', '') = v_worker.id::text
        and coalesce(n.meta->>'visa_end', '') = v_worker.visa_end::text
    )
    into v_exists;

    if not v_exists then
      insert into public.notifications (user_id, title, body, meta)
      values (
        null,
        v_title,
        v_body,
        json_build_object(
          'type', v_type,
          'worker_id', v_worker.id,
          'worker_name', v_worker.name,
          'visa_end', v_worker.visa_end
        )::jsonb
      );

      v_inserted := v_inserted + 1;
    end if;
  end loop;

  return v_inserted;
end;
$$;

grant execute on function public.sync_worker_visa_expiry_notifications() to authenticated;
grant execute on function public.sync_worker_visa_expiry_notifications() to service_role;
