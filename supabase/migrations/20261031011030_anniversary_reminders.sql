alter table public.couples add column anniversary_timezone text not null default 'Asia/Kathmandu';
create table public.anniversary_notifications(
 id uuid primary key default gen_random_uuid(),
 couple_id uuid not null references public.couples(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 anniversary_date date not null,
 kind text not null check(kind in('1month','15days','5days','3days','24h','12h')),
 due_at timestamptz not null,
 delivered_at timestamptz,lease_until timestamptz,attempts integer not null default 0,
 unique(couple_id,recipient_id,anniversary_date,kind)
);
alter table public.anniversary_notifications enable row level security;
revoke all on public.anniversary_notifications from public,anon,authenticated;
grant all on public.anniversary_notifications to service_role;
create index anniversary_due on public.anniversary_notifications(due_at) where delivered_at is null;
create index anniversary_recipient on public.anniversary_notifications(recipient_id);
create function private.anniversary_day(started date,year_number integer) returns date language sql immutable set search_path='' as $$
 select make_date(year_number,extract(month from started)::integer,least(extract(day from started)::integer,extract(day from (make_date(year_number,extract(month from started)::integer,1)+interval '1 month - 1 day'))::integer));
$$;
revoke all on function private.anniversary_day(date,integer) from public,anon,authenticated;
create function private.schedule_anniversaries(target uuid default null) returns void language sql security definer set search_path='' as $$
 insert into public.anniversary_notifications(couple_id,recipient_id,anniversary_date,kind,due_at)
 select c.id,p.id,a.day,t.kind,((a.day+time '09:00')-t.lead_time) at time zone c.anniversary_timezone
 from public.couples c join public.profiles p on p.couple_id=c.id
 cross join lateral generate_series(extract(year from now() at time zone c.anniversary_timezone)::integer,extract(year from now() at time zone c.anniversary_timezone)::integer+1) y(year_number)
 cross join lateral (select private.anniversary_day(c.started_on,y.year_number) as day) a
 cross join(values('1month',interval '1 month'),('15days',interval '15 days'),('5days',interval '5 days'),('3days',interval '3 days'),('24h',interval '24 hours'),('12h',interval '12 hours')) t(kind,lead_time)
 where c.started_on is not null and (target is null or c.id=target) and y.year_number>extract(year from c.started_on)
 and ((a.day+time '09:00')-t.lead_time) at time zone c.anniversary_timezone>now()
 on conflict do nothing;
$$;
revoke all on function private.schedule_anniversaries(uuid) from public,anon,authenticated;
create function private.reschedule_anniversary() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.started_on is distinct from old.started_on then
  delete from public.anniversary_notifications where couple_id=new.id;
  perform private.schedule_anniversaries(new.id);
 end if;
 return new;
end $$;
revoke all on function private.reschedule_anniversary() from public,anon,authenticated;
create trigger reschedule_anniversary after update of started_on on public.couples for each row execute function private.reschedule_anniversary();
create function public.claim_anniversary_notifications() returns setof public.anniversary_notifications language sql security invoker set search_path='' as $$
 update public.anniversary_notifications set lease_until=now()+interval '2 minutes',attempts=attempts+1 where id in(select id from public.anniversary_notifications where delivered_at is null and due_at<=now() and due_at>now()-interval '1 hour' and attempts<10 and (lease_until is null or lease_until<now()) order by due_at limit 30 for update skip locked) returning *;
$$;
revoke all on function public.claim_anniversary_notifications() from public,anon,authenticated;
grant execute on function public.claim_anniversary_notifications() to service_role;
create function private.dispatch_anniversary_notifications() returns void language plpgsql security definer set search_path='' as $$
declare secret text;
begin
 select decrypted_secret into secret from vault.decrypted_secrets where name='jigu_notification_secret';
 if secret is null then return;end if;
 perform net.http_post(url:='https://dtjasplpglevmtagkrfp.supabase.co/functions/v1/notify-anniversary',headers:=jsonb_build_object('content-type','application/json','x-jigu-notification-secret',secret),body:='{}'::jsonb);
end $$;
revoke all on function private.dispatch_anniversary_notifications() from public,anon,authenticated;
select cron.schedule('jigu-plan-anniversaries','5 0 * * *','select private.schedule_anniversaries()');
select cron.schedule('jigu-anniversary-reminders','* * * * *','select private.dispatch_anniversary_notifications()');
select private.schedule_anniversaries();
