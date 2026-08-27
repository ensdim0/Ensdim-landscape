-- Auto-approve a self-registered company as soon as the signup user
-- confirms their email — no super-admin action required.
--
-- Company self-registration (2026-07-30_company_self_registration.sql)
-- creates the new tenant with status 'pending', which blocks access via
-- current_tenant_id() until a platform owner flips it to 'active' from
-- platform-admin. This migration removes that manual step: Supabase Auth
-- updates auth.users.email_confirmed_at (NULL -> timestamp) the moment the
-- user clicks the confirmation link, so a trigger on that transition is
-- enough to activate the tenant automatically. The platform-admin "قبول"
-- button is left in place as a manual fallback for edge cases, it's just
-- no longer needed on the normal path.

CREATE OR REPLACE FUNCTION public.handle_email_confirmed()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL THEN
    UPDATE public.tenants
    SET status = 'active'
    WHERE status = 'pending'
      AND id = (SELECT tenant_id FROM public.users WHERE id = NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_email_confirmed ON auth.users;
CREATE TRIGGER on_auth_user_email_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  WHEN (OLD.email_confirmed_at IS DISTINCT FROM NEW.email_confirmed_at)
  EXECUTE FUNCTION public.handle_email_confirmed();
