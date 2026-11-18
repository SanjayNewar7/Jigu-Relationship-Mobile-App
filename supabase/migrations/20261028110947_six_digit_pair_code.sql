create or replace function private.generate_pair_code() returns text
language plpgsql volatile set search_path = ''
as $$
declare bytes bytea; candidate bigint; code text;
begin
  loop
    bytes := extensions.gen_random_bytes(4);
    candidate := (get_byte(bytes, 0)::bigint << 24)
      + (get_byte(bytes, 1)::bigint << 16)
      + (get_byte(bytes, 2)::bigint << 8)
      + get_byte(bytes, 3)::bigint;
    code := lpad((candidate % 1000000)::text, 6, '0');
    exit when not exists (select 1 from public.profiles where invite_code = code);
  end loop;
  return code;
end $$;
revoke all on function private.generate_pair_code() from public, anon, authenticated;

alter table public.profiles alter column invite_code set default private.generate_pair_code();
update public.profiles set invite_code = private.generate_pair_code();
alter table public.profiles add constraint invite_code_six_digits check (invite_code ~ '^[0-9]{6}$');

create table private.pair_attempts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started timestamptz not null default now(),
  attempts integer not null default 0
);
alter table private.pair_attempts enable row level security;
revoke all on private.pair_attempts from public, anon, authenticated;

create or replace function public.join_couple(invite text) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare target public.profiles; mine public.profiles; result uuid; attempt_count integer;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  insert into private.pair_attempts(user_id, window_started, attempts)
    values (auth.uid(), now(), 1)
    on conflict (user_id) do update set
      attempts = case
        when private.pair_attempts.window_started < now() - interval '10 minutes'
          then 1 else private.pair_attempts.attempts + 1 end,
      window_started = case
        when private.pair_attempts.window_started < now() - interval '10 minutes'
          then now() else private.pair_attempts.window_started end
    returning attempts into attempt_count;
  if attempt_count > 5 then return null; end if;
  if invite !~ '^[0-9]{6}$' then return null; end if;
  select * into mine from public.profiles where id = auth.uid() for update;
  if mine.couple_id is not null then raise exception 'You are already connected'; end if;
  select * into target from public.profiles
    where invite_code = invite and id <> auth.uid() for update;
  if target.id is null then return null; end if;
  if target.couple_id is null then
    insert into public.couples(person_a, person_b)
      values (target.id, auth.uid()) returning id into result;
    update public.profiles set couple_id = result
      where id in (target.id, auth.uid());
  else
    select id into result from public.couples
      where id = target.couple_id and person_a = target.id
        and person_b is null for update;
    if result is null then return null; end if;
    update public.couples set person_b = auth.uid() where id = result;
    update public.profiles set couple_id = result where id = auth.uid();
  end if;
  return result;
end $$;
