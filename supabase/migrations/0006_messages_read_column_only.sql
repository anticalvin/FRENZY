-- recipients may only change read_at, never the message body
revoke update on public.messages from authenticated, anon;
grant update (read_at) on public.messages to authenticated;
