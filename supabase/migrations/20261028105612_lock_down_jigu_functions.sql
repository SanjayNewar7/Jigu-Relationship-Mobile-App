create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter function public.is_couple_member(uuid) set schema private;
revoke all on function private.is_couple_member(uuid) from public, anon, authenticated;
grant execute on function private.is_couple_member(uuid) to authenticated;

alter function public.new_profile() set schema private;
revoke all on function private.new_profile() from public, anon, authenticated;

revoke all on function public.join_couple(text) from public, anon, authenticated;
grant execute on function public.join_couple(text) to authenticated;
