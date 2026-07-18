-- ╔══════════════════════════════════════════════════════╗
-- ║  Fleet Management: Vehicles & Vehicle Expenses     ║
-- ╚══════════════════════════════════════════════════════╝

-- ── 1. Vehicles table ──
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  plate_number TEXT NOT NULL,
  license_number TEXT NOT NULL,
  license_expiry DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── 2. Vehicle expenses table ──
CREATE TABLE IF NOT EXISTS public.vehicle_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  amount NUMERIC(12, 3) NOT NULL DEFAULT 0,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── 3. Indexes ──
CREATE INDEX IF NOT EXISTS idx_vehicle_expenses_vehicle_id ON public.vehicle_expenses(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_expenses_date ON public.vehicle_expenses(expense_date);

-- ── 4. RLS ──
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_expenses ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'vehicles' AND policyname = 'admin_all_vehicles') THEN
    CREATE POLICY admin_all_vehicles ON public.vehicles
      FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
      ));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'vehicle_expenses' AND policyname = 'admin_all_vehicle_expenses') THEN
    CREATE POLICY admin_all_vehicle_expenses ON public.vehicle_expenses
      FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
      ));
  END IF;
END $$;

-- ── 5. Grants ──
GRANT ALL ON public.vehicles TO service_role;
GRANT ALL ON public.vehicles TO authenticated;
GRANT ALL ON public.vehicle_expenses TO service_role;
GRANT ALL ON public.vehicle_expenses TO authenticated;

-- ── 6. Updated_at trigger ──
DROP TRIGGER IF EXISTS trg_vehicles_updated ON public.vehicles;
CREATE TRIGGER trg_vehicles_updated BEFORE UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
