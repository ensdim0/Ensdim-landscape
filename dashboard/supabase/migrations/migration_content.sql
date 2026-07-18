-- Update guard contact info through a security-definer RPC.
-- This avoids column-grant and RLS edge cases from direct table updates.

drop function if exists public.update_contract_guard_info(uuid, text, text);

create or replace function public.update_contract_guard_info(
  p_contract_id uuid,
  p_guard_name text,
  p_guard_phone text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  rows_updated integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  begin
    execute $sql$
      update public.contracts
      set
        contract_user_name = nullif(trim($2), ''),
        contract_user_phone = nullif(trim($3), '')
      where id = $1
        and user_id = auth.uid()
    $sql$
    using p_contract_id, p_guard_name, p_guard_phone;

    get diagnostics rows_updated = row_count;
  exception
    when undefined_column then
      rows_updated := 0;
  end;

  if rows_updated = 0 then
    begin
      execute $sql$
        update public.contracts c
        set
          contract_user_name = nullif(trim($2), ''),
          contract_user_phone = nullif(trim($3), '')
        where c.id = $1
          and exists (
            select 1
            from public.clients cl
            where cl.id = c.client_id
              and cl.user_id = auth.uid()
          )
      $sql$
      using p_contract_id, p_guard_name, p_guard_phone;

      get diagnostics rows_updated = row_count;
    exception
      when undefined_table or undefined_column then
        rows_updated := 0;
    end;
  end if;

  if rows_updated = 0 then
    raise exception 'contract_not_found_or_not_owned' using errcode = '42501';
  end if;

  return true;
end;
$$;

grant execute on function public.update_contract_guard_info(uuid, text, text) to authenticated;

