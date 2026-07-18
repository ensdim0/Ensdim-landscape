-- Enable Realtime for the notifications table so Flutter clients
-- receive live INSERT events without polling.
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
