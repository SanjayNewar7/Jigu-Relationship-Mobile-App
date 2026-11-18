-- Read only the messages represented by a notification; never consume a newer arrival.
create or replace function public.read_chat_through(space uuid, message_id uuid)
returns timestamptz language plpgsql security invoker set search_path='' as $$
declare cutoff timestamptz;
begin
  select created_at into cutoff from public.chat_messages
  where id=message_id and couple_id=space;
  if cutoff is null then raise exception 'Message unavailable'; end if;
  insert into public.chat_state(couple_id,user_id,last_seen_at,read_at,typing_until)
  values(space,auth.uid(),now(),cutoff,now())
  on conflict(couple_id,user_id) do update set
    read_at=greatest(public.chat_state.read_at,excluded.read_at);
  return cutoff;
end $$;
revoke all on function public.read_chat_through(uuid,uuid) from public,anon;
grant execute on function public.read_chat_through(uuid,uuid) to authenticated;

alter table public.notification_devices add column if not exists chat_version integer not null default 1;
revoke update on public.notification_devices from authenticated;
grant update(chat_version) on public.notification_devices to authenticated;
create policy devices_owner_capability_update on public.notification_devices
for update to authenticated using(user_id=(select auth.uid()))
with check(user_id=(select auth.uid()));
create or replace function public.enable_chat_notification_v2(device_token text)
returns void language sql security invoker set search_path='' as $$
  update public.notification_devices set chat_version=2
  where token=device_token and user_id=auth.uid();
$$;
revoke all on function public.enable_chat_notification_v2(text) from public,anon;
grant execute on function public.enable_chat_notification_v2(text) to authenticated;
