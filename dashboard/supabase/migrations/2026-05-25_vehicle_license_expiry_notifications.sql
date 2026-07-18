-- Notify admins when a vehicle license is expiring (30/15 days) or expired.

create or replace function public.sync_vehicle_license_expiry_notifications()
returns integer
language plpgsql
as $$
declare
  v_vehicle record;
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

  for v_vehicle in
    select id, plate_number, license_number, license_expiry
    from public.vehicles
    where license_expiry is not null
      and (license_expiry::date) <= current_date + 30
  loop
    v_days_left := (v_vehicle.license_expiry::date - current_date);

    if v_days_left <= 0 then
      v_type := 'vehicle_license_expired';
      v_title := format('رخصة السيارة %s منتهية', coalesce(v_vehicle.plate_number, v_vehicle.id::text));
      v_body := format('تاريخ انتهاء رخصة السيارة %s هو %s، وقد انتهت الآن.', coalesce(v_vehicle.plate_number, v_vehicle.id::text), to_char(v_vehicle.license_expiry, 'YYYY-MM-DD'));
    elsif v_days_left = 15 then
      v_type := 'vehicle_license_expiring_15';
      v_title := format('رخصة السيارة %s تنتهي خلال 15 يومًا', coalesce(v_vehicle.plate_number, v_vehicle.id::text));
      v_body := format('متبقي 15 يومًا على انتهاء رخصة السيارة %s. تاريخ الانتهاء: %s.', coalesce(v_vehicle.plate_number, v_vehicle.id::text), to_char(v_vehicle.license_expiry, 'YYYY-MM-DD'));
    elsif v_days_left = 30 then
      v_type := 'vehicle_license_expiring_30';
      v_title := format('رخصة السيارة %s تنتهي خلال 30 يومًا', coalesce(v_vehicle.plate_number, v_vehicle.id::text));
      v_body := format('متبقي 30 يومًا على انتهاء رخصة السيارة %s. تاريخ الانتهاء: %s.', coalesce(v_vehicle.plate_number, v_vehicle.id::text), to_char(v_vehicle.license_expiry, 'YYYY-MM-DD'));
    else
      continue;
    end if;

    select exists (
      select 1
      from public.notifications n
      where coalesce(n.meta->>'type','') = v_type
        and coalesce(n.meta->>'vehicle_id','') = v_vehicle.id::text
        and coalesce(n.meta->>'license_expiry','') = to_char(v_vehicle.license_expiry::date, 'YYYY-MM-DD')
    ) into v_exists;

    if not v_exists then
      insert into public.notifications (user_id, title, body, meta)
      values (
        null,
        v_title,
        v_body,
        jsonb_build_object(
          'type', v_type,
          'vehicle_id', v_vehicle.id,
          'plate_number', v_vehicle.plate_number,
          'license_number', v_vehicle.license_number,
          'license_expiry', v_vehicle.license_expiry::date,
          'days_left', v_days_left
        )::jsonb
      );

      v_inserted := v_inserted + 1;
    end if;

  end loop;

  return v_inserted;
end;
$$;

grant execute on function public.sync_vehicle_license_expiry_notifications() to authenticated;
grant execute on function public.sync_vehicle_license_expiry_notifications() to service_role;

-- Trigger-based notifier: create notifications immediately when a vehicle's license_expiry is set/changed
create or replace function public.notify_vehicle_license_expiry_on_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
  v_title text;
  v_body text;
  v_days_left integer;
  v_exists boolean;
begin
  if tg_op = 'INSERT' or (tg_op = 'UPDATE' and (old.license_expiry is distinct from new.license_expiry)) then
    if new.license_expiry is null then
      return new;
    end if;

    v_days_left := (new.license_expiry::date - current_date);

    if v_days_left <= 0 then
      v_type := 'vehicle_license_expired';
      v_title := format('رخصة السيارة %s منتهية', coalesce(new.plate_number, new.id::text));
      v_body := format('تاريخ انتهاء رخصة السيارة %s هو %s، وقد انتهت الآن.', coalesce(new.plate_number, new.id::text), to_char(new.license_expiry, 'YYYY-MM-DD'));
    elsif v_days_left = 15 then
      v_type := 'vehicle_license_expiring_15';
      v_title := format('رخصة السيارة %s تنتهي خلال 15 يومًا', coalesce(new.plate_number, new.id::text));
      v_body := format('متبقي 15 يومًا على انتهاء رخصة السيارة %s. تاريخ الانتهاء: %s.', coalesce(new.plate_number, new.id::text), to_char(new.license_expiry, 'YYYY-MM-DD'));
    elsif v_days_left = 30 then
      v_type := 'vehicle_license_expiring_30';
      v_title := format('رخصة السيارة %s تنتهي خلال 30 يومًا', coalesce(new.plate_number, new.id::text));
      v_body := format('متبقي 30 يومًا على انتهاء رخصة السيارة %s. تاريخ الانتهاء: %s.', coalesce(new.plate_number, new.id::text), to_char(new.license_expiry, 'YYYY-MM-DD'));
    else
      return new;
    end if;

    select exists (
      select 1 from public.notifications n
      where coalesce(n.meta->>'type','') = v_type
        and coalesce(n.meta->>'vehicle_id','') = new.id::text
        and coalesce(n.meta->>'license_expiry','') = to_char(new.license_expiry::date, 'YYYY-MM-DD')
    ) into v_exists;

    if not v_exists then
      insert into public.notifications (user_id, title, body, meta)
      values (
        null,
        v_title,
        v_body,
        jsonb_build_object(
          'type', v_type,
          'vehicle_id', new.id,
          'plate_number', new.plate_number,
          'license_number', new.license_number,
          'license_expiry', new.license_expiry::date,
          'days_left', v_days_left
        )::jsonb
      );

      -- If license already expired, mark vehicle status to 'inactive'
      if v_days_left <= 0 and coalesce(new.status, '') <> 'inactive' then
        update public.vehicles set status = 'inactive' where id = new.id;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_vehicle_license_expiry_on_change on public.vehicles;
create trigger trg_notify_vehicle_license_expiry_on_change
after insert or update of license_expiry on public.vehicles
for each row execute function public.notify_vehicle_license_expiry_on_change();

grant execute on function public.notify_vehicle_license_expiry_on_change() to authenticated;
grant execute on function public.notify_vehicle_license_expiry_on_change() to service_role;
