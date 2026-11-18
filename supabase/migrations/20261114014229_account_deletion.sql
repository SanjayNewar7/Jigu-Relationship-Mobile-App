-- Only the service-role Edge Function may prepare or remove an account.
-- Shared spaces belong to both people, so deletion removes every space in
-- which the departing user holds a seat and unpairs the other person.
create function public.account_deletion_assets(target_user uuid)
returns table(bucket_id text, object_name text)
language sql security definer set search_path = '' as $$
  select o.bucket_id, o.name
  from storage.objects o
  where o.bucket_id in ('moments', 'date-memories')
    and (
      o.owner_id = target_user::text
      or exists (
        select 1 from public.couples c
        where target_user in (c.person_a, c.person_b)
          and o.name like c.id::text || '/%'
      )
    );
$$;
revoke all on function public.account_deletion_assets(uuid) from public, anon, authenticated;
grant execute on function public.account_deletion_assets(uuid) to service_role;

create function public.remove_account_data(target_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from auth.users where id = target_user) then
    raise exception 'Account not found';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(710624);
  delete from public.couples
  where target_user in (person_a, person_b);
  delete from public.mood_journal_entries where user_id = target_user;
  delete from public.locations where user_id = target_user;
  delete from public.notification_devices where user_id = target_user;
  delete from private.pair_attempts where user_id = target_user;
  update public.profiles
  set couple_id = null, previous_couple_id = null, location_enabled = false
  where id = target_user;
end $$;
revoke all on function public.remove_account_data(uuid) from public, anon, authenticated;
grant execute on function public.remove_account_data(uuid) to service_role;
