-- Twenty-four uploads per couple in any rolling 24 hours; each lasts 48 hours.
alter table public.moments add column expires_at timestamptz;
update public.moments set expires_at = created_at + interval '48 hours';
alter table public.moments alter column expires_at set not null;
alter table public.moments alter column expires_at set default (now() + interval '48 hours');
create index moments_expiry on public.moments(expires_at);

alter table public.profiles add column last_active_at timestamptz;
grant update(last_active_at) on public.profiles to authenticated;
create function public.touch_presence() returns void language sql security invoker set search_path = ''
as $$ update public.profiles set last_active_at = now() where id = (select auth.uid()); $$;
revoke all on function public.touch_presence() from public, anon;
grant execute on function public.touch_presence() to authenticated;

alter table public.locations
  add column speed_mps double precision check (speed_mps >= 0 and speed_mps <= 100),
  add column accuracy_m double precision check (accuracy_m >= 0),
  add column heading double precision check (heading >= 0 and heading <= 360),
  add column recorded_at timestamptz not null default now();

create table public.moment_likes (
  moment_id uuid not null references public.moments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(moment_id,user_id)
);
create index moment_likes_user on public.moment_likes(user_id,created_at desc);
alter table public.moment_likes enable row level security;
grant select,insert,delete on public.moment_likes to authenticated;

create function private.can_read_moment(target uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.moments m
    where m.id=target and private.is_couple_member(m.couple_id)
      and (m.expires_at > now() or exists(select 1 from public.moment_likes l
        where l.moment_id=m.id and l.user_id=(select auth.uid()))));
$$;
revoke all on function private.can_read_moment(uuid) from public,anon;
grant execute on function private.can_read_moment(uuid) to authenticated;
drop policy moments_read on public.moments;
create policy moments_read on public.moments for select to authenticated using(private.can_read_moment(id));
create policy likes_read on public.moment_likes for select to authenticated
using (user_id=(select auth.uid()) or exists(select 1 from public.moments m
  where m.id=moment_id and m.expires_at > now() and private.is_couple_member(m.couple_id)));
create policy likes_insert on public.moment_likes for insert to authenticated
with check(user_id=(select auth.uid()) and exists(select 1 from public.moments m
  where m.id=moment_id and m.expires_at > now() and private.is_couple_member(m.couple_id)));
create policy likes_delete on public.moment_likes for delete to authenticated using(user_id=(select auth.uid()));

create function private.enforce_moment_limits() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_couple_member(new.couple_id) or new.author_id is distinct from auth.uid() then
    raise exception 'You can only share a moment with your own partner';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.couple_id::text,0));
  if (select count(*) from public.moments where couple_id=new.couple_id and created_at > now()-interval '24 hours') >=24 then
    raise exception 'You have shared 24 photos in the last 24 hours. A slot opens when your oldest upload reaches 24 hours.';
  end if;
  new.created_at=now(); new.expires_at=now()+interval '48 hours';
  return new;
end $$;
revoke all on function private.enforce_moment_limits() from public,anon,authenticated;
create trigger enforce_moment_limits before insert on public.moments for each row execute function private.enforce_moment_limits();

-- Serialize likes with expiry so a saved favorite cannot race with deletion.
create function private.guard_moment_like() returns trigger
language plpgsql security definer set search_path = '' as $$
declare expiry timestamptz; couple uuid;
begin
  select expires_at,couple_id into expiry,couple from public.moments where id=new.moment_id for update;
  if expiry is null or expiry<=clock_timestamp() or new.user_id is distinct from auth.uid() or not private.is_couple_member(couple) then
    raise exception 'This moment is no longer available to like';
  end if;
  new.created_at=now(); return new;
end $$;
revoke all on function private.guard_moment_like() from public,anon,authenticated;
create trigger guard_moment_like before insert on public.moment_likes for each row execute function private.guard_moment_like();

drop policy moments_storage_read on storage.objects;
create policy moments_storage_read on storage.objects for select to authenticated
using(bucket_id='moments' and exists(select 1 from public.moments m where m.storage_path=name and private.can_read_moment(m.id)));
-- Permit cleanup of an upload if its database insert fails (e.g. rolling quota).
create function private.is_unlinked_photo(path text) returns boolean
language sql stable security definer set search_path = ''
as $$ select not exists(select 1 from public.moments where storage_path=path); $$;
revoke all on function private.is_unlinked_photo(text) from public,anon;
grant execute on function private.is_unlinked_photo(text) to authenticated;
create policy moments_storage_delete_own_orphan on storage.objects for delete to authenticated
using(bucket_id='moments' and owner_id=(select auth.uid())::text
  and private.is_unlinked_photo(name));

create table private.moment_cleanup_queue (
  storage_path text primary key,
  queued_at timestamptz not null default now()
);
alter table private.moment_cleanup_queue enable row level security;
revoke all on private.moment_cleanup_queue from public,anon,authenticated;
grant usage on schema private to service_role;
grant select,delete on private.moment_cleanup_queue to service_role;

create function private.expire_moments() returns integer
language plpgsql security definer set search_path = '' as $$
declare item record; deleted integer:=0;
begin
  for item in select id,storage_path from public.moments where expires_at<=now() for update skip locked loop
    if not exists(select 1 from public.moment_likes where moment_id=item.id) then
      insert into private.moment_cleanup_queue(storage_path) values(item.storage_path) on conflict do nothing;
      delete from public.moments where id=item.id;
      deleted=deleted+1;
    end if;
  end loop;
  insert into private.moment_cleanup_queue(storage_path)
    select o.name from storage.objects o where o.bucket_id='moments' and o.created_at<now()-interval '48 hours'
      and not exists(select 1 from public.moments m where m.storage_path=o.name)
    on conflict do nothing;
  return deleted;
end $$;
revoke all on function private.expire_moments() from public,anon,authenticated;

create function public.pending_moment_cleanup() returns table(storage_path text)
language sql security invoker set search_path = ''
as $$ select storage_path from private.moment_cleanup_queue order by queued_at limit 100; $$;
create function public.complete_moment_cleanup(paths text[]) returns void
language sql security invoker set search_path = ''
as $$ delete from private.moment_cleanup_queue where storage_path=any(paths); $$;
revoke all on function public.pending_moment_cleanup() from public,anon,authenticated;
revoke all on function public.complete_moment_cleanup(text[]) from public,anon,authenticated;
grant execute on function public.pending_moment_cleanup() to service_role;
grant execute on function public.complete_moment_cleanup(text[]) to service_role;

alter publication supabase_realtime add table public.moment_likes;
alter publication supabase_realtime add table public.profiles;
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
select cron.schedule('jigu-expire-moments','* * * * *','select private.expire_moments();');
