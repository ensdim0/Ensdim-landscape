-- Security fix: contract-images / payment-receipts UPDATE and DELETE storage
-- policies were never tenant-scoped.
--
-- 2026-07-21_multi_tenant_storage.sql fixed SELECT (read) access for these
-- buckets to require same-tenant ownership, but deliberately left the older
-- UPDATE/DELETE policies from 2026-03-01_contract_image.sql and
-- 2026-06-18_upayments_integration.sql untouched ("any authenticated user").
-- That means any logged-in user from ANY tenant could overwrite or delete
-- another tenant's contract image or payment receipt if they knew (or
-- guessed) the object path. This closes that gap using the same ownership
-- join already used by the SELECT policies.

DROP POLICY IF EXISTS "Authenticated users can update contract images" ON storage.objects;
CREATE POLICY "Tenant scoped update contract images" ON storage.objects FOR UPDATE TO authenticated USING (
  bucket_id = 'contract-images'
  AND EXISTS (
    SELECT 1 FROM public.contracts c
    WHERE c.id = public.storage_path_uuid(storage.objects.name)
      AND c.tenant_id = public.current_tenant_id()
  )
);

DROP POLICY IF EXISTS "Authenticated users can delete contract images" ON storage.objects;
CREATE POLICY "Tenant scoped delete contract images" ON storage.objects FOR DELETE TO authenticated USING (
  bucket_id = 'contract-images'
  AND EXISTS (
    SELECT 1 FROM public.contracts c
    WHERE c.id = public.storage_path_uuid(storage.objects.name)
      AND c.tenant_id = public.current_tenant_id()
  )
);

DROP POLICY IF EXISTS "Authenticated update receipts" ON storage.objects;
CREATE POLICY "Tenant scoped update receipts" ON storage.objects FOR UPDATE TO authenticated USING (
  bucket_id = 'payment-receipts'
  AND (
    EXISTS (SELECT 1 FROM contract_payments cp WHERE cp.id = public.storage_path_uuid(storage.objects.name) AND cp.tenant_id = public.current_tenant_id())
    OR EXISTS (SELECT 1 FROM standalone_task_payments stp WHERE stp.id = public.storage_path_uuid(storage.objects.name) AND stp.tenant_id = public.current_tenant_id())
  )
);
