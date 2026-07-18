-- Add first_visit_date column to contracts table
ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS first_visit_date date;

-- Recreate contracts_view to include the new column
DROP VIEW IF EXISTS public.contracts_view CASCADE;

CREATE VIEW public.contracts_view AS
SELECT
  c.id,
  c.user_id,
  c.block_id,
  c.code,
  c.contract_type_id,
  c.status,
  c.duration_months,
  c.address_details,
  c.block_number,
  c.street,
  c.avenue,
  c.house,
  c.kuwait_finder_url,
  c.contract_user_name,
  c.contract_user_phone,
  c.contract_user_password_hash,
  c.start_date,
  c.first_visit_date,
  c.end_date,
  c.total_value,
  c.terms,
  c.contract_image_url,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  coalesce(c.zone_id, b.zone_id) AS zone_id,
  z.line_id,
  u.full_name AS client_name,
  u.email AS client_email,
  u.phone AS client_phone
FROM public.contracts c
LEFT JOIN public.blocks b ON b.id = c.block_id
LEFT JOIN public.zones z ON z.id = coalesce(c.zone_id, b.zone_id)
LEFT JOIN public.users u ON u.id = c.user_id
WHERE c.deleted_at IS NULL;

GRANT SELECT ON public.contracts_view TO authenticated;
