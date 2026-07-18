-- Allow cancelled contracts while preserving legacy terminated rows.
ALTER TABLE public.contracts DROP CONSTRAINT IF EXISTS contracts_status_check;

ALTER TABLE public.contracts ADD CONSTRAINT contracts_status_check
  CHECK (status IN ('active', 'pending', 'expired', 'terminated', 'cancelled'));
