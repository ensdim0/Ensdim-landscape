-- Allow clients to read standalone tasks linked to their own contracts.

ALTER TABLE public.standalone_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clients read own standalone tasks" ON public.standalone_tasks;

CREATE POLICY "Clients read own standalone tasks"
ON public.standalone_tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.contracts c
    WHERE c.id = public.standalone_tasks.contract_id
      AND c.user_id = auth.uid()
  )
);