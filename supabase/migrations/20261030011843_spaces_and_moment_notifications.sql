-- Space membership is independent of authentication. Original seats stay reserved.
alter table public.profiles add column previous_couple_id uuid references public.couples(id) on delete set null;
create index profiles_previous_couple on public.profiles(previous_couple_id);
create or replace function private.is_couple_member(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p join public.couples c on c.id=p.couple_id
 where p.id=(select auth.uid()) and p.couple_id=target and p.id in(c.person_a,c.person_b));
$$;
drop policy couples_read on public.couples;
create policy couples_read on public.couples for select to authenticated using(private.is_couple_member(id));

create function public.leave_couple() returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(710624);
 update public.profiles set previous_couple_id=couple_id,couple_id=null,location_enabled=false
 where id=auth.uid() and couple_id is not null;
 delete from public.locations where user_id=auth.uid();
end $$;
revoke all on function public.leave_couple() from public,anon;
grant execute on function public.leave_couple() to authenticated;

create or replace function public.join_couple(invite text) returns uuid
language plpgsql security definer set search_path='' as $$
declare mine public.profiles; target public.profiles; result uuid; attempt_count integer;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- Serialize this tiny two-person app's pairing operations to avoid inverse lock deadlocks.
 perform pg_catalog.pg_advisory_xact_lock(710624);
 insert into private.pair_attempts(user_id,window_started,attempts) values(auth.uid(),now(),1)
 on conflict(user_id) do update set
 attempts=case when private.pair_attempts.window_started<now()-interval '10 minutes' then 1 else private.pair_attempts.attempts+1 end,
 window_started=case when private.pair_attempts.window_started<now()-interval '10 minutes' then now() else private.pair_attempts.window_started end
 returning attempts into attempt_count;
 if attempt_count>5 or invite !~ '^[0-9]{6}$' then return null; end if;
 select * into mine from public.profiles where id=auth.uid() for update;
 if mine.couple_id is not null then raise exception 'Leave your current space first'; end if;
 select * into target from public.profiles where invite_code=invite and id<>auth.uid() for update;
 if target.id is null then return null; end if;
 select c.id into result from public.couples c
 where auth.uid() in(c.person_a,c.person_b) and target.id in(c.person_a,c.person_b)
 and c.id=coalesce(mine.previous_couple_id,target.couple_id,target.previous_couple_id) for update;
 if result is not null then
   if target.couple_id is not null and target.couple_id<>result then return null; end if;
   update public.profiles set couple_id=result,previous_couple_id=null,location_enabled=false where id=auth.uid();
   return result;
 end if;
 if mine.previous_couple_id is not null or target.previous_couple_id is not null or target.couple_id is not null then return null; end if;
 insert into public.couples(person_a,person_b) values(target.id,auth.uid()) returning id into result;
 update public.profiles set couple_id=result where id in(target.id,auth.uid());
 return result;
end $$;

create table public.notification_devices(
 token text primary key check(length(token) between 20 and 4096),
 user_id uuid not null references auth.users(id) on delete cascade,
 platform text not null check(platform in('android','ios')),
 updated_at timestamptz not null default now()
);
create index notification_devices_user on public.notification_devices(user_id);
alter table public.notification_devices enable row level security;
grant select,delete on public.notification_devices to authenticated;
create policy devices_owner_read on public.notification_devices for select to authenticated using(user_id=(select auth.uid()));
create policy devices_owner_delete on public.notification_devices for delete to authenticated using(user_id=(select auth.uid()));
create function public.register_notification_device(device_token text,device_platform text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 insert into public.notification_devices(token,user_id,platform) values(device_token,auth.uid(),device_platform)
 on conflict(token) do update set user_id=auth.uid(),platform=excluded.platform,updated_at=now();
end $$;
revoke all on function public.register_notification_device(text,text) from public,anon;
grant execute on function public.register_notification_device(text,text) to authenticated;

create table public.moment_notifications(
 id uuid primary key default gen_random_uuid(),
 moment_id uuid not null references public.moments(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 delivered_at timestamptz,
 attempts integer not null default 0,
 unique(moment_id,recipient_id)
);
create index notifications_pending on public.moment_notifications(created_at) where delivered_at is null;
create index notifications_recipient on public.moment_notifications(recipient_id);
alter table public.moment_notifications enable row level security;
grant select on public.moment_notifications to authenticated;
create policy notifications_owner on public.moment_notifications for select to authenticated using(recipient_id=(select auth.uid()) and exists(select 1 from public.moments m where m.id=moment_id and private.is_couple_member(m.couple_id)));
create function private.queue_moment_notification() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.moment_notifications(moment_id,recipient_id)
 select new.id,p.id from public.profiles p where p.couple_id=new.couple_id and p.id<>new.author_id;
 return new;
end $$;
revoke all on function private.queue_moment_notification() from public,anon,authenticated;
create trigger moment_notification after insert on public.moments for each row execute function private.queue_moment_notification();
