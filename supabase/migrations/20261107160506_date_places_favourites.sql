alter table public.date_invitations add column heading text
 check (heading is null or length(trim(heading)) between 3 and 160);

create table public.date_places (
 id uuid primary key default gen_random_uuid(),
 couple_id uuid not null references public.couples(id) on delete cascade,
 created_by uuid not null references auth.users(id) on delete cascade,
 name text not null check (length(trim(name)) between 2 and 160),
 address text not null check (length(trim(address)) between 3 and 300),
 latitude double precision not null check (latitude between -90 and 90),
 longitude double precision not null check (longitude between -180 and 180),
 category text not null default 'Our place' check (length(category) between 2 and 32),
 source text not null default 'manual' check (source in ('manual','nearby')),
 is_favorite boolean not null default true,
 created_at timestamptz not null default now()
);
create index date_places_favorites on public.date_places(couple_id, is_favorite, created_at desc);
alter table public.date_places enable row level security;
revoke all on public.date_places from anon;
grant select, insert, delete on public.date_places to authenticated;
grant update (name, address, latitude, longitude, category, is_favorite) on public.date_places to authenticated;
create policy date_places_read on public.date_places for select to authenticated
 using (private.is_couple_member(couple_id));
create policy date_places_add on public.date_places for insert to authenticated
 with check (private.is_couple_member(couple_id) and created_by = (select auth.uid()));
create policy date_places_change on public.date_places for update to authenticated
 using (private.is_couple_member(couple_id))
 with check (private.is_couple_member(couple_id));
create policy date_places_remove on public.date_places for delete to authenticated
 using (private.is_couple_member(couple_id));
