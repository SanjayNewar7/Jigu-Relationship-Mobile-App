alter table public.moment_notifications add column lease_until timestamptz;
grant all on public.notification_devices,public.moment_notifications to service_role;
create function public.claim_moment_notifications() returns setof public.moment_notifications
language sql security invoker set search_path='' as $$
 update public.moment_notifications set lease_until=now()+interval '2 minutes',attempts=attempts+1
 where id in(select id from public.moment_notifications where delivered_at is null and attempts<10
 and created_at>now()-interval '1 hour' and (lease_until is null or lease_until<now())
 order by created_at limit 30 for update skip locked) returning *;
$$;
revoke all on function public.claim_moment_notifications() from public,anon,authenticated;
grant execute on function public.claim_moment_notifications() to service_role;

create function private.dispatch_moment_notifications() returns void
language plpgsql security definer set search_path='' as $$
declare secret text;
begin
 select decrypted_secret into secret from vault.decrypted_secrets where name='jigu_notification_secret';
 if secret is null then return; end if;
 perform net.http_post(url:='https://dtjasplpglevmtagkrfp.supabase.co/functions/v1/notify-moment',
 headers:=jsonb_build_object('content-type','application/json','x-jigu-notification-secret',secret),body:='{}'::jsonb);
end $$;
revoke all on function private.dispatch_moment_notifications() from public,anon,authenticated;
create function private.wake_notification_worker() returns trigger
language plpgsql security definer set search_path='' as $$
begin perform private.dispatch_moment_notifications(); return new; end $$;
revoke all on function private.wake_notification_worker() from public,anon,authenticated;
create trigger dispatch_notification after insert on public.moment_notifications
for each statement execute function private.wake_notification_worker();
select cron.schedule('jigu-moment-notifications','* * * * *','select private.dispatch_moment_notifications()');
