-- Store standalone task schedule as date+time (instead of date only).
-- This preserves existing rows by converting DATE to TIMESTAMP at 00:00.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'standalone_tasks'
      AND column_name = 'task_date'
      AND data_type = 'date'
  ) THEN
    ALTER TABLE public.standalone_tasks
      ALTER COLUMN task_date TYPE TIMESTAMP WITHOUT TIME ZONE
      USING task_date::timestamp;
  END IF;
END $$;

COMMENT ON COLUMN public.standalone_tasks.task_date IS 'Task scheduled date and time';
