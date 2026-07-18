-- Allow contract owner (client) to read visit artifacts:
-- 1) visit-level photos
-- 2) task executions
-- 3) task execution photos

-- Visit photos readable by contract owner
DROP POLICY IF EXISTS client_read_visit_photos ON public.visit_photos;
CREATE POLICY client_read_visit_photos
ON public.visit_photos
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.visits v
    JOIN public.contracts c ON c.id = v.contract_id
    WHERE v.id = visit_photos.visit_id
      AND c.user_id = auth.uid()
  )
);

-- Task executions readable by contract owner
DROP POLICY IF EXISTS client_read_task_executions ON public.task_executions;
CREATE POLICY client_read_task_executions
ON public.task_executions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.contract_tasks ct
    JOIN public.contracts c ON c.id = ct.contract_id
    WHERE ct.id = task_executions.task_id
      AND c.user_id = auth.uid()
  )
);

-- Task photos readable by contract owner
DROP POLICY IF EXISTS client_read_task_photos ON public.task_photos;
CREATE POLICY client_read_task_photos
ON public.task_photos
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.task_executions te
    JOIN public.contract_tasks ct ON ct.id = te.task_id
    JOIN public.contracts c ON c.id = ct.contract_id
    WHERE te.id = task_photos.execution_id
      AND c.user_id = auth.uid()
  )
);
