-- Allow admins to read broadcast notifications (user_id IS NULL) while keeping per-user privacy.

DROP POLICY IF EXISTS "Authenticated read notifications" ON public.notifications;

CREATE POLICY "Authenticated read notifications"
  ON public.notifications
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR (user_id IS NULL AND public.is_admin())
  );
