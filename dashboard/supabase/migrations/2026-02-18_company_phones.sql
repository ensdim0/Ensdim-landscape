-- ╔══════════════════════════════════════════════════════╗
-- ║  Company Phones Management                         ║
-- ╚══════════════════════════════════════════════════════╝

-- ── 1. Company phones table ──
CREATE TABLE IF NOT EXISTS public.company_phones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  phone_number TEXT NOT NULL,
  phone_name TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── 2. Link geographic_lines to company_phones ──
ALTER TABLE public.geographic_lines
ADD COLUMN phone_id UUID REFERENCES public.company_phones(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_geographic_lines_phone_id ON public.geographic_lines(phone_id);

-- ── 3. RLS ──
ALTER TABLE public.company_phones ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'company_phones' AND policyname = 'admin_all_company_phones') THEN
    CREATE POLICY admin_all_company_phones ON public.company_phones
      FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
      ));
  END IF;
END $$;

-- ── 4. Grants ──
GRANT ALL ON public.company_phones TO service_role;
GRANT ALL ON public.company_phones TO authenticated;

-- ── 5. Updated_at trigger ──
DROP TRIGGER IF EXISTS trg_company_phones_updated ON public.company_phones;
CREATE TRIGGER trg_company_phones_updated BEFORE UPDATE ON public.company_phones
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
