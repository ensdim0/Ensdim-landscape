-- ─────────────────────────────────────────
-- expense_sections: admin-managed expense categories
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expense_sections (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT        NOT NULL,
  type       TEXT        NOT NULL DEFAULT 'general'
             CHECK (type IN ('general', 'salary', 'vehicles')),
  sort_order INT         NOT NULL DEFAULT 0,
  is_system  BOOLEAN     NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE expense_sections ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON expense_sections TO authenticated;

DROP POLICY IF EXISTS "Admins manage expense sections" ON expense_sections;
CREATE POLICY "Admins manage expense sections"
  ON expense_sections FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Seed default sections matching existing hardcoded categories
INSERT INTO expense_sections (name, type, sort_order, is_system) VALUES
  ('العمالة',  'salary',   1, true),
  ('الإيجار',  'general',  2, false),
  ('التسويق',  'general',  3, false),
  ('متنوعة',   'general',  4, false),
  ('السيارات', 'vehicles', 5, true)
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────
-- expense_line_items: items under each section
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expense_line_items (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id UUID        NOT NULL REFERENCES expense_sections(id) ON DELETE CASCADE,
  name       TEXT        NOT NULL,
  sort_order INT         NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE expense_line_items ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON expense_line_items TO authenticated;

DROP POLICY IF EXISTS "Admins manage expense line items" ON expense_line_items;
CREATE POLICY "Admins manage expense line items"
  ON expense_line_items FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ─────────────────────────────────────────
-- Add section_id + line_item_id to company_expenses
-- Keep category column for salary bulk-pay logic compatibility
-- ─────────────────────────────────────────
ALTER TABLE company_expenses
  ADD COLUMN IF NOT EXISTS section_id    UUID REFERENCES expense_sections(id)   ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS line_item_id  UUID REFERENCES expense_line_items(id) ON DELETE SET NULL;

-- Allow category to be null for new custom-section expenses
ALTER TABLE company_expenses DROP CONSTRAINT IF EXISTS company_expenses_category_check;
ALTER TABLE company_expenses ALTER COLUMN category DROP NOT NULL;

-- Migrate existing records to point to their corresponding section
UPDATE company_expenses e
SET section_id = s.id
FROM expense_sections s
WHERE s.name = 'العمالة'  AND e.category = 'salary'   AND e.section_id IS NULL;

UPDATE company_expenses e
SET section_id = s.id
FROM expense_sections s
WHERE s.name = 'الإيجار'  AND e.category = 'rent'     AND e.section_id IS NULL;

UPDATE company_expenses e
SET section_id = s.id
FROM expense_sections s
WHERE s.name = 'التسويق'  AND e.category = 'marketing' AND e.section_id IS NULL;

UPDATE company_expenses e
SET section_id = s.id
FROM expense_sections s
WHERE s.name = 'متنوعة'   AND e.category = 'misc'     AND e.section_id IS NULL;

-- ─────────────────────────────────────────
-- Add line_item_id to vehicle_expenses
-- ─────────────────────────────────────────
ALTER TABLE vehicle_expenses
  ADD COLUMN IF NOT EXISTS line_item_id UUID REFERENCES expense_line_items(id) ON DELETE SET NULL;
