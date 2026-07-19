-- Hotfix for 2026-07-19_multi_tenant_foundation.sql: that migration made
-- tenant_id NOT NULL on 30 tables but gave it no DEFAULT. Since the app does
-- not set tenant_id on inserts yet (that lands in later phases), every new
-- row created through the dashboard/mobile app since that migration ran
-- would fail with a not-null violation. This adds a DEFAULT of the Ensdim
-- tenant so existing app code keeps working unchanged until it's updated to
-- pass tenant_id explicitly. Run this immediately.

DO $$
DECLARE
  ensdim_tenant_id CONSTANT uuid := 'faf164d1-64f3-4b35-99c7-242118dd76c5';
  t text;
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
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN tenant_id SET DEFAULT %L', t, ensdim_tenant_id);
  END LOOP;
END;
$$;
