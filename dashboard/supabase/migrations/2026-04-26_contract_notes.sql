-- Add optional internal notes on contracts and expose it in contracts_view.

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS notes text;

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
  c.notes,
  c.block_number,
  c.street,
  c.avenue,
  c.house,
  c.kuwait_finder_url,
  c.contract_user_name,
  c.contract_user_phone,
  c.start_date,
  c.first_visit_date,
  c.end_date,
  c.total_value,
  c.terms,
  c.contract_image_url,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  COALESCE(c.zone_id, b.zone_id) AS zone_id,
  z.line_id,
  u.full_name AS client_name,
  u.email AS client_email,
  u.phone AS client_phone
FROM public.contracts c
LEFT JOIN public.blocks b ON b.id = c.block_id
LEFT JOIN public.zones z ON z.id = COALESCE(c.zone_id, b.zone_id)
LEFT JOIN public.users u ON u.id = c.user_id
WHERE c.deleted_at IS NULL;

GRANT SELECT ON public.contracts_view TO authenticated;
REVOKE SELECT ON public.contracts_view FROM anon;
