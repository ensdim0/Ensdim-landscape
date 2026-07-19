-- Fix: the hotfix migration (2026-07-19b) gave tenant_id a DEFAULT hardcoded
-- to the Ensdim tenant on every table. That's correct only for Ensdim's own
-- admin — any OTHER tenant's admin creating anything (contract types,
-- zones, contracts, ...) got a row silently defaulted to Ensdim's tenant_id
-- instead of their own, which the RLS WITH CHECK then correctly rejects
-- with a 403 (tenant mismatch).
--
-- Fix: make the default resolve to whoever is actually creating the row
-- (public.current_tenant_id(), based on their own session) instead of a
-- single hardcoded tenant. This keeps Ensdim's behavior byte-for-byte
-- identical (an Ensdim admin's current_tenant_id() is still Ensdim's id)
-- while making every other tenant work correctly too.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users', 'geographic_lines', 'zones', 'blocks', 'contract_types', 'contracts',
    'assets', 'visits', 'contract_tasks', 'task_executions', 'task_photos',
    'visit_photos', 'client_comments', 'supervisor_notes', 'assignments', 'reports',
    'contract_status_requests', 'standalone_tasks', 'standalone_task_payments',
    'invoices', 'payments', 'contract_payments', 'company_phones', 'vehicles',
    'vehicle_expenses', 'workers', 'company_expenses', 'expense_sections',
    'expense_line_items'
    -- contact_requests is deliberately excluded: it's filled in by the
    -- public/anonymous lead form (no logged-in session, so
    -- current_tenant_id() would be NULL for those inserts) — it keeps its
    -- static Ensdim default from the hotfix migration on purpose.
  ]
  LOOP
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id()', t);
  END LOOP;
END;
$$;
