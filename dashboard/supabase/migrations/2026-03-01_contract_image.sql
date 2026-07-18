-- Add contract image URL column
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS contract_image_url TEXT;

-- Recreate contracts_view to include the new column
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
  c.contract_image_url,
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

GRANT SELECT ON public.contracts_view TO authenticated;
GRANT SELECT ON public.contracts_view TO anon;
GRANT SELECT ON public.contracts_view TO service_role;

-- Create storage bucket for contract images
INSERT INTO storage.buckets (id, name, public)
VALUES ('contract-images', 'contract-images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload files
CREATE POLICY "Authenticated users can upload contract images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'contract-images');

-- Allow authenticated users to update/overwrite files
CREATE POLICY "Authenticated users can update contract images"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'contract-images');

-- Allow public read access
CREATE POLICY "Public read access for contract images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'contract-images');

-- Allow authenticated users to delete their uploads
CREATE POLICY "Authenticated users can delete contract images"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'contract-images');
