-- Add optional contract linkage and cost to standalone_tasks
ALTER TABLE public.standalone_tasks
  ADD COLUMN IF NOT EXISTS contract_id UUID REFERENCES public.contracts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cost NUMERIC(12,2);

CREATE INDEX IF NOT EXISTS idx_standalone_tasks_contract ON public.standalone_tasks(contract_id);

COMMENT ON COLUMN public.standalone_tasks.contract_id IS 'Linked contract (اختياري)';
COMMENT ON COLUMN public.standalone_tasks.cost IS 'Task cost (تكلفة)';
