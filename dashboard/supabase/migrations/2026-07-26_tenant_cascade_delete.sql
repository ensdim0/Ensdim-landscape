-- Lets a platform owner permanently delete a tenant (company) and every row
-- that belongs to it in one shot. The tenant_id foreign keys added in
-- 2026-07-19_multi_tenant_foundation.sql had no ON DELETE behavior (default
-- NO ACTION), so `DELETE FROM tenants` would just fail with a foreign key
-- violation today. Switching to CASCADE makes `DELETE FROM public.tenants
-- WHERE id = ...` wipe the tenant's contracts, visits, payments, photos,
-- users, everything — which is exactly what "delete this company" should
-- mean. This is a genuinely destructive, irreversible operation; the
-- platform-delete-company edge function is the only sanctioned way to
-- trigger it (requires typing the tenant's slug to confirm).

DO $$
DECLARE
  t text;
  fkname text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users', 'geographic_lines', 'zones', 'blocks', 'contract_types', 'contracts',
    'assets', 'visits', 'contract_tasks', 'task_executions', 'task_photos',
    'visit_photos', 'client_comments', 'supervisor_notes', 'assignments', 'reports',
    'contract_status_requests', 'standalone_tasks', 'standalone_task_payments',
    'invoices', 'payments', 'contract_payments', 'company_phones', 'vehicles',
    'vehicle_expenses', 'workers', 'company_expenses', 'expense_sections',
    'expense_line_items', 'contact_requests'
  ]
  LOOP
    fkname := t || '_tenant_id_fkey';
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', t, fkname);
    EXECUTE format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE',
      t, fkname
    );
  END LOOP;
END;
$$;

-- notifications.tenant_id was added separately (2026-07-20) with a plain FK
-- (no ON DELETE clause) — switch it to CASCADE too.
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_tenant_id_fkey;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

-- private.tenant_payment_settings already declared ON DELETE CASCADE inline
-- when it was created (2026-07-23) — nothing to change there.
