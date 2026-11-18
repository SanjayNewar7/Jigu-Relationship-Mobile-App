-- Trigger helper does not belong in the public Data API.
revoke all on function public.rls_auto_enable() from public, anon, authenticated;
