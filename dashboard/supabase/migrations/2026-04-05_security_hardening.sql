-- Security hardening (non-breaking):
-- 1) Remove sensitive columns from exposed views.
-- 2) Revoke anonymous access to internal views/tables.
-- 3) Keep authenticated app behavior unchanged.

ALTER TABLE public.contracts ADD COLUMN IF NOT EXISTS first_visit_date date;

-- Recreate contracts_view without exposing contract_user_password_hash.
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
REVOKE SELECT ON public.contracts_view FROM anon;

-- Revoke broad anonymous visibility to internal data surfaces.
REVOKE SELECT ON public.users_view FROM anon;
REVOKE SELECT ON public.invoices_view FROM anon;
REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM anon;

-- Anonymous users do not need this helper in production.
REVOKE EXECUTE ON FUNCTION public.is_admin() FROM anon;

-- Make task photos bucket private and readable by authenticated users only.
UPDATE storage.buckets SET public = false WHERE id = 'task-photos';

DROP POLICY IF EXISTS "Public Access to task photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated read task photos" ON storage.objects;
CREATE POLICY "Authenticated read task photos"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'task-photos');
