-- Notify admins and contract owner when a contract is expiring (30/15 days) or expired.

create or replace function public.sync_contract_expiry_notifications()
returns integer
language plpgsql
as $$
declare
  v_contract record;
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

  for v_contract in
    select id, code, end_date, user_id
    from public.contracts
    where end_date is not null
      and (end_date::date) <= current_date + 30
  loop
    v_days_left := (v_contract.end_date::date - current_date);

    if v_days_left <= 0 then
      v_type := 'contract_expired';
      v_title := format('العقد %s منتهي', coalesce(v_contract.code, v_contract.id::text));
      v_body := format('تاريخ انتهاء العقد %s هو %s، وقد انتهى الآن.', coalesce(v_contract.code, v_contract.id::text), to_char(v_contract.end_date, 'YYYY-MM-DD'));
    elsif v_days_left = 15 then
      v_type := 'contract_expiring_15';
      v_title := format('العقد %s ينتهي خلال 15 يومًا', coalesce(v_contract.code, v_contract.id::text));
      v_body := format('متبقي 15 يومًا على انتهاء العقد %s. تاريخ الانتهاء: %s.', coalesce(v_contract.code, v_contract.id::text), to_char(v_contract.end_date, 'YYYY-MM-DD'));
    elsif v_days_left = 30 then
      v_type := 'contract_expiring_30';
      v_title := format('العقد %s ينتهي خلال 30 يومًا', coalesce(v_contract.code, v_contract.id::text));
      v_body := format('متبقي 30 يومًا على انتهاء العقد %s. تاريخ الانتهاء: %s.', coalesce(v_contract.code, v_contract.id::text), to_char(v_contract.end_date, 'YYYY-MM-DD'));
    else
      -- only create notifications at 30/15 days or on expiry
      continue;
    end if;

    select exists (
      select 1
      from public.notifications n
      where coalesce(n.meta->>'type', '') = v_type
        and coalesce(n.meta->>'contract_id', '') = v_contract.id::text
        and coalesce(n.meta->>'end_date', '') = to_char(v_contract.end_date::date, 'YYYY-MM-DD')
    )
    into v_exists;

    if not v_exists then
      insert into public.notifications (user_id, title, body, meta)
      values (
        null,
        v_title,
        v_body,
        jsonb_build_object(
          'type', v_type,
          'contract_id', v_contract.id,
          'contract_code', v_contract.code,
          'end_date', v_contract.end_date::date,
          'days_left', v_days_left
        )::jsonb
      );

      v_inserted := v_inserted + 1;
    end if;

    -- also notify contract owner when present
    if v_contract.user_id is not null then
      select exists (
        select 1 from public.notifications n
        where coalesce(n.meta->>'type','') = v_type
          and n.user_id = v_contract.user_id
          and coalesce(n.meta->>'contract_id','') = v_contract.id::text
          and coalesce(n.meta->>'end_date','') = to_char(v_contract.end_date::date, 'YYYY-MM-DD')
      ) into v_exists;

      if not v_exists then
        insert into public.notifications (user_id, title, body, meta)
        values (
          v_contract.user_id,
          v_title,
          v_body,
          jsonb_build_object(
            'type', v_type,
            'contract_id', v_contract.id,
            'contract_code', v_contract.code,
            'end_date', v_contract.end_date::date,
            'days_left', v_days_left
          )::jsonb
        );

        v_inserted := v_inserted + 1;
      end if;
    end if;

  end loop;

  return v_inserted;
end;
$$;

grant execute on function public.sync_contract_expiry_notifications() to authenticated;
grant execute on function public.sync_contract_expiry_notifications() to service_role;

-- Trigger-based notifier: create notifications immediately when a contract's end_date is set/changed
create or replace function public.notify_contract_expiry_on_change()
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
  -- Only act when end_date is provided
  if tg_op = 'INSERT' or (tg_op = 'UPDATE' and (old.end_date is distinct from new.end_date)) then
    if new.end_date is null then
      return new;
    end if;

    v_days_left := (new.end_date::date - current_date);

    if v_days_left <= 0 then
      v_type := 'contract_expired';
      v_title := format('العقد %s منتهي', coalesce(new.code, new.id::text));
      v_body := format('تاريخ انتهاء العقد %s هو %s، وقد انتهى الآن.', coalesce(new.code, new.id::text), to_char(new.end_date, 'YYYY-MM-DD'));
    elsif v_days_left = 15 then
      v_type := 'contract_expiring_15';
      v_title := format('العقد %s ينتهي خلال 15 يومًا', coalesce(new.code, new.id::text));
      v_body := format('متبقي 15 يومًا على انتهاء العقد %s. تاريخ الانتهاء: %s.', coalesce(new.code, new.id::text), to_char(new.end_date, 'YYYY-MM-DD'));
    elsif v_days_left = 30 then
      v_type := 'contract_expiring_30';
      v_title := format('العقد %s ينتهي خلال 30 يومًا', coalesce(new.code, new.id::text));
      v_body := format('متبقي 30 يومًا على انتهاء العقد %s. تاريخ الانتهاء: %s.', coalesce(new.code, new.id::text), to_char(new.end_date, 'YYYY-MM-DD'));
    else
      -- no notification for other offsets
      return new;
    end if;

    -- avoid duplicate notifications for same contract + end_date + type
    select exists (
      select 1 from public.notifications n
      where coalesce(n.meta->>'type','') = v_type
        and coalesce(n.meta->>'contract_id','') = new.id::text
        and coalesce(n.meta->>'end_date','') = to_char(new.end_date::date, 'YYYY-MM-DD')
    ) into v_exists;

    if not v_exists then
      insert into public.notifications (user_id, title, body, meta)
      select
        ur.user_id,
        v_title,
        v_body,
        jsonb_build_object(
          'type', v_type,
          'contract_id', new.id,
          'contract_code', new.code,
          'end_date', new.end_date::date,
          'days_left', v_days_left
        )::jsonb
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where r.name = 'admin';

      -- notify contract owner when present
      if new.user_id is not null then
        insert into public.notifications (user_id, title, body, meta)
        values (
          new.user_id,
          v_title,
          v_body,
          jsonb_build_object(
            'type', v_type,
            'contract_id', new.id,
            'contract_code', new.code,
            'end_date', new.end_date,
            'days_left', v_days_left
          )::jsonb
        );
      end if;

      -- If contract has already expired, mark its status to 'expired'
      if v_days_left <= 0 and coalesce(new.status, '') <> 'expired' then
        update public.contracts set status = 'expired' where id = new.id;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_contract_expiry_on_change on public.contracts;
create trigger trg_notify_contract_expiry_on_change
after insert or update of end_date on public.contracts
for each row execute function public.notify_contract_expiry_on_change();

grant execute on function public.notify_contract_expiry_on_change() to authenticated;
grant execute on function public.notify_contract_expiry_on_change() to service_role;
