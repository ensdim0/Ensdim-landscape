-- Explicit table grants for edge function service role access.
-- Supabase auto-grants service_role, but this ensures the new columns
-- added by the UPayments migration are accessible to edge functions.

GRANT SELECT, INSERT, UPDATE ON public.contract_payments          TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.standalone_task_payments   TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.notifications              TO service_role;
GRANT SELECT                 ON public.contracts                  TO service_role;
GRANT SELECT                 ON public.users                      TO service_role;
GRANT SELECT                 ON public.user_roles                 TO service_role;
GRANT SELECT                 ON public.roles                      TO service_role;
GRANT SELECT                 ON public.standalone_tasks           TO service_role;

-- Allow service_role to call the payment-due notifications helper
GRANT EXECUTE ON FUNCTION public.sync_payment_due_notifications()         TO service_role;
GRANT EXECUTE ON FUNCTION public.notify_payment_scheduled_on_insert()     TO service_role;
