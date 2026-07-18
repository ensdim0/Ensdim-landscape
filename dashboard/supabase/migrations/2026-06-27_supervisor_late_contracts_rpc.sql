-- RPC for the supervisor mobile app: returns IDs of contracts (within the
-- calling supervisor's assigned line) that have at least one payment past
-- its due_date and not yet paid. Avoids granting supervisors direct SELECT
-- access to contract_payments (which holds amounts/financial details).

CREATE OR REPLACE FUNCTION public.get_late_contract_ids_for_supervisor()
RETURNS TABLE(contract_id uuid)
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT cp.contract_id
  FROM contract_payments cp
  JOIN contracts c ON c.id = cp.contract_id
  JOIN zones z ON z.id = c.zone_id
  WHERE cp.due_date IS NOT NULL
    AND cp.due_date < current_date
    AND (cp.gateway_status IS NULL OR cp.gateway_status IN ('pending', 'failed', 'cancelled'))
    AND z.line_id = (SELECT u.assigned_line_id FROM users u WHERE u.id = auth.uid());
$$;

GRANT EXECUTE ON FUNCTION public.get_late_contract_ids_for_supervisor() TO authenticated;
