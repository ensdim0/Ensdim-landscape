-- Allow authenticated clients to confirm their OWN pending gateway payment.
-- USING: must be 'pending' and belong to the calling user's contract.
-- WITH CHECK: after update, gateway_status must be 'paid'.
-- This means clients can ONLY transition pending→paid for their own payments.

CREATE POLICY "Client confirm gateway payment"
ON public.contract_payments
FOR UPDATE TO authenticated
USING (
    gateway_status = 'pending'
    AND EXISTS (
        SELECT 1 FROM public.contracts c
        WHERE c.id = contract_id
          AND c.user_id = auth.uid()
    )
)
WITH CHECK (gateway_status = 'paid');

CREATE POLICY "Client confirm standalone gateway payment"
ON public.standalone_task_payments
FOR UPDATE TO authenticated
USING (
    gateway_status = 'pending'
    AND EXISTS (
        SELECT 1 FROM public.standalone_tasks st
        WHERE st.id = task_id
          AND st.client_id = auth.uid()
    )
)
WITH CHECK (gateway_status = 'paid');
