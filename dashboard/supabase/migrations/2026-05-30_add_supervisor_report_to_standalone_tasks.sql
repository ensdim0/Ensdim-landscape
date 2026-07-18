-- Add supervisor report field to standalone_tasks
ALTER TABLE public.standalone_tasks
  ADD COLUMN IF NOT EXISTS supervisor_report text;

COMMENT ON COLUMN public.standalone_tasks.supervisor_report IS 'Supervisor report entered when marking a standalone task completed or cancelled (تقرير المشرف)';
