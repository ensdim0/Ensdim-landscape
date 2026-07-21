-- Periodic retention cleanup for tables that grow without bound.
--
-- `notifications` and `audit_logs` have no row cap, so they eat into the
-- 500MB Free tier database allowance over time. Unread notifications are
-- kept forever (never delete something the user hasn't seen yet); audit
-- logs get a longer retention window since they're a compliance trail.
--
-- Invoked by the `cleanup-old-data` Edge Function on a daily schedule
-- (configured in Supabase Dashboard → Edge Functions → Schedule).

create or replace function public.cleanup_old_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.notifications
  where read = true and created_at < now() - interval '90 days';

  delete from public.audit_logs
  where created_at < now() - interval '180 days';
end;
$$;

grant execute on function public.cleanup_old_data() to service_role;
