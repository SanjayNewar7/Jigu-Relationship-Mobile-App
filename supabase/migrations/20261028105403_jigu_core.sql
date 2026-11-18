-- Jigu's couple data and private photo storage.
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.couples (
  id uuid primary key default gen_random_uuid(),
  person_a uuid not null references auth.users(id) on delete cascade,
  person_b uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint distinct_people check (person_a is distinct from person_b)
);
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  invite_code text not null unique default upper(encode(extensions.gen_random_bytes(6), 'hex')),
  couple_id uuid references public.couples(id) on delete set null,
  location_enabled boolean not null default false
);
create table if not exists public.moments (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  created_at timestamptz not null default now()
);
create table if not exists public.locations (
  user_id uuid primary key references auth.users(id) on delete cascade,
  couple_id uuid not null references public.couples(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  updated_at timestamptz not null default now()
);
create index if not exists moments_couple_created on public.moments(couple_id, created_at desc);
create index if not exists locations_couple on public.locations(couple_id);

create or replace function public.stamp_location() returns trigger
language plpgsql set search_path = ''
as $$ begin new.updated_at = now(); return new; end $$;
create trigger stamp_location_before_write before insert or update on public.locations
for each row execute function public.stamp_location();

create or replace function public.is_couple_member(target uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.couples c where c.id = target and auth.uid() in (c.person_a, c.person_b)) $$;
revoke all on function public.is_couple_member(uuid) from public;
grant execute on function public.is_couple_member(uuid) to authenticated;

create or replace function public.new_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$ begin insert into public.profiles(id) values (new.id); return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.new_profile();

create or replace function public.join_couple(invite text) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare target public.profiles; mine public.profiles; result uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into mine from public.profiles where id = auth.uid() for update;
  select * into target from public.profiles where invite_code = upper(trim(invite)) and id <> auth.uid() for update;
  if target.id is null then raise exception 'Invite code not found'; end if;
  if mine.couple_id is not null then raise exception 'You are already connected'; end if;
  if target.couple_id is null then
    insert into public.couples(person_a, person_b) values(target.id, auth.uid()) returning id into result;
    update public.profiles set couple_id = result where id in (target.id, auth.uid());
  else
    select id into result from public.couples where id = target.couple_id and person_a = target.id and person_b is null for update;
    if result is null then raise exception 'This person is already connected'; end if;
    update public.couples set person_b = auth.uid() where id = result;
    update public.profiles set couple_id = result where id = auth.uid();
  end if;
  return result;
end $$;
revoke all on function public.join_couple(text) from public;
grant execute on function public.join_couple(text) to authenticated;

alter table public.couples enable row level security;
alter table public.profiles enable row level security;
alter table public.moments enable row level security;
alter table public.locations enable row level security;
create policy couples_read on public.couples for select to authenticated using (auth.uid() in (person_a, person_b));
create policy profiles_read_couple on public.profiles for select to authenticated using (id = auth.uid() or (couple_id is not null and public.is_couple_member(couple_id)));
create policy profiles_update_self on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy moments_read on public.moments for select to authenticated using (public.is_couple_member(couple_id));
create policy moments_insert on public.moments for insert to authenticated with check (author_id = auth.uid() and public.is_couple_member(couple_id) and storage_path like couple_id::text || '/%');
create policy locations_read on public.locations for select to authenticated using (public.is_couple_member(couple_id) and exists(select 1 from public.profiles p where p.id = user_id and p.location_enabled));
create policy locations_insert on public.locations for insert to authenticated with check (user_id = auth.uid() and public.is_couple_member(couple_id) and exists(select 1 from public.profiles p where p.id = auth.uid() and p.location_enabled));
create policy locations_update on public.locations for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid() and public.is_couple_member(couple_id) and exists(select 1 from public.profiles p where p.id = auth.uid() and p.location_enabled));
create policy locations_delete on public.locations for delete to authenticated using (user_id = auth.uid());

insert into storage.buckets(id, name, public) values ('moments', 'moments', false) on conflict (id) do nothing;
create policy moments_storage_read on storage.objects for select to authenticated using (bucket_id = 'moments' and public.is_couple_member((split_part(name, '/', 1))::uuid));
create policy moments_storage_insert on storage.objects for insert to authenticated with check (bucket_id = 'moments' and public.is_couple_member((split_part(name, '/', 1))::uuid));

grant select on public.couples, public.profiles, public.moments, public.locations to authenticated;
revoke update on public.profiles from authenticated;
grant update(location_enabled) on public.profiles to authenticated;
grant insert on public.moments, public.locations to authenticated;
grant update, delete on public.locations to authenticated;
alter publication supabase_realtime add table public.moments;
alter publication supabase_realtime add table public.locations;
