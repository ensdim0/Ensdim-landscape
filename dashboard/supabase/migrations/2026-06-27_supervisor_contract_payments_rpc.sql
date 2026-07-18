-- RPC for the supervisor mobile app: returns the payments of a single
-- contract, restricted to contracts within the calling supervisor's
-- assigned line. Lets supervisors view payment status/amounts per contract
-- without granting them direct SELECT access to contract_payments.

CREATE OR REPLACE FUNCTION public.get_contract_payments_for_supervisor(p_contract_id uuid)
RETURNS TABLE(
  id uuid,
  amount numeric,
  payment_method text,
  payment_date date,
  due_date date,
  gateway_status text,
  notes text,
  created_at timestamptz
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT cp.id, cp.amount, cp.payment_method, cp.payment_date, cp.due_date, cp.gateway_status, cp.notes, cp.created_at
  FROM contract_payments cp
  JOIN contracts c ON c.id = cp.contract_id
  JOIN zones z ON z.id = c.zone_id
  WHERE cp.contract_id = p_contract_id
    AND z.line_id = (SELECT u.assigned_line_id FROM users u WHERE u.id = auth.uid())
  ORDER BY cp.due_date ASC NULLS LAST, cp.payment_date DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_contract_payments_for_supervisor(uuid) TO authenticated;
