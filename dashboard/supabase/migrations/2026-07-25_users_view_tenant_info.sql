-- Expose tenant_id/tenant name on users_view so the dashboard can show
-- which company the logged-in user belongs to (branding, and useful for
-- defense-in-depth checks client-side). Safe to add: the view already
-- filters to the caller's own tenant only (see the multi-tenant RLS
-- migration), so every row returned already belongs to that tenant.

DROP VIEW IF EXISTS public.users_view CASCADE;
CREATE VIEW public.users_view AS
SELECT
  u.id,
  u.full_name AS "fullName",
  u.email,
  u.phone,
  r.name AS role,
  u.assigned_line_id AS "assignedLineId",
  u.assignment_start_date AS "assignmentStartDate",
  u.assignment_end_date AS "assignmentEndDate",
  u.created_at AS "createdAt",
  u.tenant_id AS "tenantId",
  t.name AS "tenantName"
FROM public.users u
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
LEFT JOIN public.roles r ON r.id = ur.role_id
LEFT JOIN public.tenants t ON t.id = u.tenant_id
WHERE u.deleted_at IS NULL
  AND u.tenant_id = public.current_tenant_id();

GRANT SELECT ON public.users_view TO authenticated;
