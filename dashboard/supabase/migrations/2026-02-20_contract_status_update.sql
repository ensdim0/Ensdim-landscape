-- Update contract statuses: remove draft/paused/completed, use pending/active/terminated/expired

-- 1. Drop any existing CHECK constraint on status
ALTER TABLE public.contracts DROP CONSTRAINT IF EXISTS contracts_status_check;

-- 2. Update existing data
UPDATE public.contracts SET status = 'pending' WHERE status = 'draft';
UPDATE public.contracts SET status = 'expired' WHERE status = 'completed';
UPDATE public.contracts SET status = 'terminated' WHERE status = 'paused';

-- 3. Add new CHECK constraint with correct values
ALTER TABLE public.contracts ADD CONSTRAINT contracts_status_check
  CHECK (status IN ('active', 'pending', 'terminated', 'expired'));
