-- Hotfix: infinite recursion in the standalone_task_assignees RLS policy
-- introduced by 2026-08-26_standalone_task_teams.sql.
--
-- supervisor_view_own_team let a supervisor see every row of their task's
-- team (not just their own row) by subquerying standalone_task_assignees
-- again inside its own USING clause. Postgres re-applies RLS to that inner
-- subquery too, which re-evaluates the same policy, which subqueries the
-- table again — unbounded. Postgres detects this and raises "infinite
-- recursion detected in policy for relation standalone_task_assignees",
-- which surfaces as a 500 from PostgREST on ANY query that touches
-- standalone_task_assignees, including indirectly — standalone_tasks,
-- standalone_task_items and standalone_task_photos' policies all subquery
-- standalone_task_assignees to check team membership, so a plain
-- `select * from standalone_tasks` (even as admin) fails too.
--
-- Fix: move the membership check into a SECURITY DEFINER function. Its
-- internal query runs with the function owner's privileges, bypassing RLS
-- entirely — the same mechanism already used by confirm_gateway_payment()
-- in 2026-06-18_confirm_gateway_payment_rpc.sql — so it answers "is this
-- caller on this task's team" directly instead of re-triggering the very
-- policy that's asking the question.

CREATE OR REPLACE FUNCTION public.is_standalone_task_team_supervisor(p_task_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM standalone_task_assignees sta
    WHERE sta.task_id = p_task_id AND sta.supervisor_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_standalone_task_team_supervisor(UUID) TO authenticated;

DROP POLICY IF EXISTS supervisor_view_own_team ON public.standalone_task_assignees;
CREATE POLICY supervisor_view_own_team ON public.standalone_task_assignees
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.is_standalone_task_team_supervisor(standalone_task_assignees.task_id)
  );
