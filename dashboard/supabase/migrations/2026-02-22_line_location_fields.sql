-- Ensure contract_user columns exist (may be missing on live DB)
ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS contract_user_name TEXT,
  ADD COLUMN IF NOT EXISTS contract_user_phone TEXT,
  ADD COLUMN IF NOT EXISTS contract_user_password_hash TEXT;

-- Add location/address fields to contracts
ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS block_number TEXT,
  ADD COLUMN IF NOT EXISTS street TEXT,
  ADD COLUMN IF NOT EXISTS avenue TEXT,
  ADD COLUMN IF NOT EXISTS house TEXT,
  ADD COLUMN IF NOT EXISTS kuwait_finder_url TEXT;

-- Update contracts_view to include new fields
DROP VIEW IF EXISTS public.contracts_view;
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
  c.end_date,
  c.total_value,
  c.terms,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  coalesce(c.zone_id, b.zone_id) AS zone_id,
  z.line_id,
  u.full_name AS client_name,
  u.email AS client_email
FROM public.contracts c
LEFT JOIN public.blocks b ON b.id = c.block_id
LEFT JOIN public.zones z ON z.id = coalesce(c.zone_id, b.zone_id)
LEFT JOIN public.users u ON u.id = c.user_id
WHERE c.deleted_at IS NULL;
-- Re-grant permissions on the recreated view
GRANT SELECT ON public.contracts_view TO authenticated;
GRANT SELECT ON public.contracts_view TO anon;
GRANT SELECT ON public.contracts_view TO service_role;
