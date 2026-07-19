-- Multi-tenant SaaS conversion — Phase 3: storage isolation.
--
-- Every bucket policy today only checks bucket_id — any authenticated user
-- (contract-images: even anonymous/public!) can read any object in the
-- bucket regardless of which contract/payment/visit it belongs to. This
-- adds real ownership joins so reads are scoped to the caller's own tenant.
-- Upload (INSERT) policies are left as "any authenticated user" — the
-- confidentiality risk is in READING other tenants' files, not in the
-- upload path itself, and object paths encode the owning row's ID which is
-- validated by the app before it ever gets to a URL a client could reuse.

-- Safe helper: first path segment as uuid, or NULL if it doesn't parse
-- (avoids a malformed/legacy path throwing an error inside an RLS policy).
CREATE OR REPLACE FUNCTION public.storage_path_uuid(p_name text)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN ((storage.foldername(p_name))[1])::uuid;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- task-photos: paths are referenced from either task_photos.photo_path or
-- visit_photos.photo_path depending on which client wrote them.
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Authenticated read task photos" ON storage.objects;
DROP POLICY IF EXISTS "Tenant scoped read task photos" ON storage.objects;
CREATE POLICY "Tenant scoped read task photos" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'task-photos'
  AND (
    EXISTS (SELECT 1 FROM public.task_photos tp WHERE tp.photo_path = storage.objects.name AND tp.tenant_id = public.current_tenant_id())
    OR EXISTS (SELECT 1 FROM public.visit_photos vp WHERE vp.photo_path = storage.objects.name AND vp.tenant_id = public.current_tenant_id())
  )
);

-- ═══════════════════════════════════════════════════════════════════════
-- visit-photos bucket
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Tenant scoped read visit photos" ON storage.objects;
CREATE POLICY "Tenant scoped read visit photos" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'visit-photos'
  AND EXISTS (SELECT 1 FROM public.visit_photos vp WHERE vp.photo_path = storage.objects.name AND vp.tenant_id = public.current_tenant_id())
);

DROP POLICY IF EXISTS "Authenticated upload visit photos" ON storage.objects;
DROP POLICY IF EXISTS "Tenant scoped upload visit photos" ON storage.objects;
CREATE POLICY "Tenant scoped upload visit photos" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'visit-photos');

-- ═══════════════════════════════════════════════════════════════════════
-- contract-images: was PUBLIC (even unauthenticated!) read access — fixed
-- to require auth + same-tenant contract ownership. Path is
-- `${contractId}/${fileName}`.
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Public read access for contract images" ON storage.objects;
DROP POLICY IF EXISTS "Tenant scoped read contract images" ON storage.objects;
CREATE POLICY "Tenant scoped read contract images" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'contract-images'
  AND EXISTS (
    SELECT 1 FROM public.contracts c
    WHERE c.id = public.storage_path_uuid(storage.objects.name)
      AND c.tenant_id = public.current_tenant_id()
  )
);

-- ═══════════════════════════════════════════════════════════════════════
-- payment-images / payment-receipts: path is `${paymentId}/${fileName}`,
-- paymentId may be a contract_payments.id or a standalone_task_payments.id.
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Anyone can view payment images" ON storage.objects;
DROP POLICY IF EXISTS "Tenant scoped read payment images" ON storage.objects;
CREATE POLICY "Tenant scoped read payment images" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'payment-images'
  AND (
    EXISTS (SELECT 1 FROM contract_payments cp WHERE cp.id = public.storage_path_uuid(storage.objects.name) AND cp.tenant_id = public.current_tenant_id())
    OR EXISTS (SELECT 1 FROM standalone_task_payments stp WHERE stp.id = public.storage_path_uuid(storage.objects.name) AND stp.tenant_id = public.current_tenant_id())
  )
);

DROP POLICY IF EXISTS "Authenticated view receipts" ON storage.objects;
DROP POLICY IF EXISTS "Tenant scoped read payment receipts" ON storage.objects;
CREATE POLICY "Tenant scoped read payment receipts" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'payment-receipts'
  AND (
    EXISTS (SELECT 1 FROM contract_payments cp WHERE cp.id = public.storage_path_uuid(storage.objects.name) AND cp.tenant_id = public.current_tenant_id())
    OR EXISTS (SELECT 1 FROM standalone_task_payments stp WHERE stp.id = public.storage_path_uuid(storage.objects.name) AND stp.tenant_id = public.current_tenant_id())
  )
);
