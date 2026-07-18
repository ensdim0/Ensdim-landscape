-- Add optional line and zone linkage to standalone_tasks
ALTER TABLE public.standalone_tasks
  ADD COLUMN IF NOT EXISTS line_id UUID REFERENCES public.geographic_lines(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS zone_id UUID REFERENCES public.zones(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_standalone_tasks_line ON public.standalone_tasks(line_id);
CREATE INDEX IF NOT EXISTS idx_standalone_tasks_zone ON public.standalone_tasks(zone_id);

COMMENT ON COLUMN public.standalone_tasks.line_id IS 'Associated geographic line (optional)';
COMMENT ON COLUMN public.standalone_tasks.zone_id IS 'Associated zone (optional)';
