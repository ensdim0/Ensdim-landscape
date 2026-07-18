-- Add kind column to expense_sections to distinguish expense vs cost sections
ALTER TABLE expense_sections
  ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'expense';

-- Add check constraint if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'expense_sections_kind_check'
  ) THEN
    ALTER TABLE expense_sections
      ADD CONSTRAINT expense_sections_kind_check CHECK (kind IN ('expense', 'cost'));
  END IF;
END$$;

-- Existing sections remain 'expense' (default covers them)
-- No data migration needed
