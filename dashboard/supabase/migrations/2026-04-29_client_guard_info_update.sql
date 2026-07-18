-- Allow clients to update only the guard contact fields on their own contract.

-- Ensure RLS is enabled so row-level policies take effect (no-op if already enabled)
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;

-- Grant column-limited update to authenticated role
GRANT SELECT, UPDATE (contract_user_name, contract_user_phone) ON public.contracts TO authenticated;

DROP POLICY IF EXISTS "Clients update own guard info" ON public.contracts;
CREATE POLICY "Clients update own guard info"
ON public.contracts
FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());