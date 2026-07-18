-- Add address field to standalone tasks
ALTER TABLE public.standalone_tasks
ADD COLUMN IF NOT EXISTS address TEXT;

COMMENT ON COLUMN public.standalone_tasks.address IS 'Task address / العنوان';
