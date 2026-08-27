-- Expand confirm_standalone_task_payment() to accept the same manual
-- payment methods the rest of the system uses (cash/transfer/cheque/card —
-- see PAYMENT_METHOD_OPTIONS in dashboard/src/presentation/screens/admin/
-- AssignTaskPage.tsx and StandaloneTaskDetailsPage.tsx), not just
-- cash/transfer. 'gateway' is intentionally excluded — that's the online
-- checkout flow (confirm_gateway_payment RPC), not something a supervisor
-- manually confirms in the field.

CREATE OR REPLACE FUNCTION public.confirm_standalone_task_payment(
  p_task_id UUID,
  p_payment_method TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(confirmed BOOLEAN, payment_status TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rows INTEGER := 0;
  v_cost NUMERIC;
BEGIN
  IF p_payment_method NOT IN ('cash', 'transfer', 'cheque', 'card') THEN
    RAISE EXCEPTION 'invalid payment method: %', p_payment_method;
  END IF;

  UPDATE standalone_tasks st
  SET payment_status = 'paid',
      payment_method = p_payment_method,
      payment_confirmed_at = now(),
      payment_confirmed_by = auth.uid()
  WHERE st.id = p_task_id
    AND st.status = 'completed'
    AND st.payment_status = 'unpaid'
    AND st.tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM standalone_task_assignees sta
      WHERE sta.task_id = st.id AND sta.supervisor_id = auth.uid()
    )
  RETURNING st.cost INTO v_cost;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows > 0 THEN
    INSERT INTO standalone_task_payments (task_id, amount, payment_method, notes, payment_date)
    VALUES (p_task_id, COALESCE(v_cost, 0), p_payment_method, p_notes, CURRENT_DATE);
  END IF;

  RETURN QUERY
  SELECT v_rows > 0, st.payment_status
  FROM standalone_tasks st
  WHERE st.id = p_task_id
    AND st.tenant_id = public.current_tenant_id()
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM standalone_task_assignees sta
        WHERE sta.task_id = st.id AND sta.supervisor_id = auth.uid()
      )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_standalone_task_payment(UUID, TEXT, TEXT) TO authenticated;
