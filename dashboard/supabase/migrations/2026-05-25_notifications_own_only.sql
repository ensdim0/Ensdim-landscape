-- Fix notifications SELECT policy: every user (including admins) sees only their own notifications.
-- Previously, is_admin() allowed admins to see all users' notifications.

DROP POLICY IF EXISTS "Authenticated read notifications" ON public.notifications;

CREATE POLICY "Authenticated read notifications"
  ON public.notifications
  FOR SELECT
  USING (user_id = auth.uid());
