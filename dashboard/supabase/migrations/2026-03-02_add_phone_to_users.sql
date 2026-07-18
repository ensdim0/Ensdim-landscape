-- Add phone column to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT;

-- Recreate users_view to include phone
DROP VIEW IF EXISTS public.users_view;

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
    u.created_at AS "createdAt"
FROM public.users u
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
LEFT JOIN public.roles r ON r.id = ur.role_id
WHERE u.deleted_at IS NULL;

GRANT SELECT ON public.users_view TO authenticated;
GRANT SELECT ON public.users_view TO anon;
