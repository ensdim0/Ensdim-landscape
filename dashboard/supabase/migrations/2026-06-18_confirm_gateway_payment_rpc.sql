-- RPC callable by authenticated clients to confirm their own gateway payment.
-- SECURITY DEFINER bypasses RLS; security is enforced inside the function via
-- ownership checks so a client can only mark their OWN pending payments as paid.

CREATE OR REPLACE FUNCTION public.confirm_gateway_payment(
    p_payment_id   UUID,
    p_payment_type TEXT   -- 'contract' or 'standalone'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rows INTEGER := 0;
BEGIN
    IF p_payment_type = 'contract' THEN
        -- Only the contract owner can confirm; payment must be in 'pending' state
        UPDATE contract_payments
        SET
            gateway_status = 'paid',
            payment_method = 'gateway',
            payment_date   = CURRENT_DATE,
            due_date       = NULL
        WHERE
            id             = p_payment_id
            AND gateway_status = 'pending'
            AND EXISTS (
                SELECT 1 FROM contracts c
                WHERE c.id = contract_payments.contract_id
                  AND c.user_id = auth.uid()
            );
        GET DIAGNOSTICS v_rows = ROW_COUNT;

    ELSIF p_payment_type = 'standalone' THEN
        -- Only the task client can confirm; payment must be in 'pending' state
        UPDATE standalone_task_payments stp
        SET
            gateway_status = 'paid',
            payment_method = 'gateway',
            payment_date   = CURRENT_DATE,
            due_date       = NULL
        WHERE
            stp.id             = p_payment_id
            AND stp.gateway_status = 'pending'
            AND EXISTS (
                SELECT 1 FROM standalone_tasks st
                WHERE st.id = stp.task_id
                  AND st.client_id = auth.uid()
            );
        GET DIAGNOSTICS v_rows = ROW_COUNT;

        -- Cascade to the task itself when the payment was confirmed
        IF v_rows > 0 THEN
            UPDATE standalone_tasks st
            SET payment_status = 'paid', payment_method = 'gateway'
            FROM standalone_task_payments stp
            WHERE stp.id    = p_payment_id
              AND st.id     = stp.task_id;
        END IF;
    ELSE
        RETURN FALSE;
    END IF;

    RETURN v_rows > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_gateway_payment(UUID, TEXT) TO authenticated;
