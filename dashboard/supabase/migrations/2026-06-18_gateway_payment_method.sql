-- Store UPayments session_id (for status check) and actual payment method (knet/cc/google_pay)

ALTER TABLE contract_payments
  ADD COLUMN IF NOT EXISTS gateway_session_id     TEXT,
  ADD COLUMN IF NOT EXISTS gateway_payment_method TEXT;

ALTER TABLE standalone_task_payments
  ADD COLUMN IF NOT EXISTS gateway_session_id     TEXT,
  ADD COLUMN IF NOT EXISTS gateway_payment_method TEXT;

GRANT UPDATE (gateway_session_id, gateway_payment_method) ON public.contract_payments          TO service_role;
GRANT UPDATE (gateway_session_id, gateway_payment_method) ON public.standalone_task_payments   TO service_role;
GRANT SELECT (gateway_session_id, gateway_payment_method) ON public.contract_payments          TO authenticated;
GRANT SELECT (gateway_session_id, gateway_payment_method) ON public.standalone_task_payments   TO authenticated;
