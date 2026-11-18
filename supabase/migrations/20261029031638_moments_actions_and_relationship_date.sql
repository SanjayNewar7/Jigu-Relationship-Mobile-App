-- Shared relationship anniversary, editable by either partner.
alter table public.couples add column started_on date;
alter table public.couples add constraint couples_started_on_not_future check (started_on is null or started_on <= current_date);
revoke update on public.couples from public, authenticated;
grant update(started_on) on public.couples to authenticated;
create policy couples_set_started_on on public.couples for update to authenticated
  using (id in (select couple_id from public.profiles where id = (select auth.uid())))
  with check (id in (select couple_id from public.profiles where id = (select auth.uid())));

-- Soft deletion hides a moment from both feeds without erasing a partner's liked copy.
-- Keep the row for at least 24 hours so deleting cannot reset the rolling upload quota.
alter table public.moments add column deleted_at timestamptz;
create index if not exists moments_couple_created on public.moments(couple_id, created_at desc);
revoke update, delete on public.moments from public, authenticated;
grant update(deleted_at) on public.moments to authenticated;
create policy moments_hide_author on public.moments for update to authenticated
  using (author_id = (select auth.uid()) and deleted_at is null and private.is_couple_member(couple_id))
  with check (author_id = (select auth.uid()) and private.is_couple_member(couple_id));
create function private.stamp_moment_deletion() returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if old.deleted_at is not null then raise exception 'This moment is already removed'; end if;
  new.deleted_at = clock_timestamp();
  return new;
end $$;
revoke all on function private.stamp_moment_deletion() from public, anon, authenticated;
create trigger stamp_moment_deletion before update of deleted_at on public.moments
for each row execute function private.stamp_moment_deletion();

create or replace function private.can_read_moment(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.moments m
    where m.id=target and private.is_couple_member(m.couple_id)
      and ((m.deleted_at is null and m.expires_at > now())
           or exists(select 1 from public.moment_likes l
                     where l.moment_id=m.id and l.user_id=(select auth.uid()))));
$$;
create or replace function private.guard_moment_like() returns trigger
language plpgsql security definer set search_path = '' as $$
declare expiry timestamptz; couple uuid; removed timestamptz;
begin
  select expires_at,couple_id,deleted_at into expiry,couple,removed from public.moments where id=new.moment_id for update;
  if expiry is null or expiry<=clock_timestamp() or removed is not null
     or new.user_id is distinct from auth.uid() or not private.is_couple_member(couple) then
    raise exception 'This moment is no longer available to like';
  end if;
  new.created_at=now(); return new;
end $$;
drop policy likes_read on public.moment_likes;
create policy likes_read on public.moment_likes for select to authenticated
using (user_id=(select auth.uid()) or exists(select 1 from public.moments m
  where m.id=moment_id and m.deleted_at is null and m.expires_at > now() and private.is_couple_member(m.couple_id)));
drop policy likes_insert on public.moment_likes;
create policy likes_insert on public.moment_likes for insert to authenticated
with check(user_id=(select auth.uid()) and exists(select 1 from public.moments m
  where m.id=moment_id and m.deleted_at is null and m.expires_at > now() and private.is_couple_member(m.couple_id)));

create or replace function private.expire_moments() returns integer
language plpgsql security definer set search_path = '' as $$
declare item record; deleted integer:=0;
begin
  for item in select id,storage_path from public.moments
    where expires_at<=now() or (deleted_at is not null and created_at<=now()-interval '24 hours')
    for update skip locked loop
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

