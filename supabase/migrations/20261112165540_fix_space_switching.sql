-- A previous space is history, not a restriction on forming a new pair.
-- Original seats and their private history are never reassigned to another user.
create or replace function private.try_join_space(invite text) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare
  mine public.profiles;
  target public.profiles;
  result uuid;
  attempt_count integer;
  attempt_start timestamptz;
  code text := pg_catalog.btrim(coalesce(invite, ''));
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(710624);
  select * into mine from public.profiles where id = auth.uid() for update;
  if mine.id is null then return jsonb_build_object('status', 'profile_missing'); end if;
  if mine.couple_id is not null then
    return jsonb_build_object('status', 'already_in_space');
  end if;
  insert into private.pair_attempts(user_id, window_started, attempts)
  values(auth.uid(), now(), 1)
  on conflict(user_id) do update set
    attempts = case when private.pair_attempts.window_started < now() - interval '10 minutes'
      then 1 else private.pair_attempts.attempts + 1 end,
    window_started = case when private.pair_attempts.window_started < now() - interval '10 minutes'
      then now() else private.pair_attempts.window_started end
  returning attempts, window_started into attempt_count, attempt_start;
  if attempt_count > 5 then
    return jsonb_build_object('status', 'rate_limited', 'retry_after_seconds',
      greatest(1, ceil(extract(epoch from attempt_start + interval '10 minutes' - now()))));
  end if;
  if code !~ '^[0-9]{6}$' then return jsonb_build_object('status', 'invalid_code'); end if;
  if code = mine.invite_code then return jsonb_build_object('status', 'own_code'); end if;
  select * into target from public.profiles where invite_code = code and id <> auth.uid() for update;
  if target.id is null then return jsonb_build_object('status', 'invalid_code'); end if;

  -- An active target can only welcome their original partner back.
  if target.couple_id is not null then
    select c.id into result from public.couples c
    where c.id = target.couple_id and mine.id in (c.person_a, c.person_b)
      and target.id in (c.person_a, c.person_b) for update;
    if result is null then return jsonb_build_object('status', 'target_unavailable'); end if;
  else
    -- Search all historical spaces, not just the most recently left space.
    select c.id into result from public.couples c
    where mine.id in (c.person_a, c.person_b) and target.id in (c.person_a, c.person_b)
    order by (c.id = mine.previous_couple_id) desc nulls last, c.created_at desc, c.id
    limit 1 for update;
  end if;

  if result is null then
    insert into public.couples(person_a, person_b) values(target.id, mine.id) returning id into result;
    update public.profiles set couple_id = result, previous_couple_id = null, location_enabled = false
    where id in (mine.id, target.id);
    delete from public.locations where user_id in (mine.id, target.id);
  else
    -- Rejoining does not silently restore a partner who deliberately left.
    update public.profiles set couple_id = result, previous_couple_id = null, location_enabled = false
    where id = mine.id;
    delete from public.locations where user_id = mine.id;
  end if;
  delete from private.pair_attempts where user_id = mine.id;
  return jsonb_build_object('status', 'joined', 'space_id', result);
end;
$$;
revoke all on function private.try_join_space(text) from public, anon, authenticated;

create or replace function public.join_couple_v2(invite text) returns jsonb
language sql security definer set search_path = '' as $$
  select private.try_join_space(invite);
$$;
revoke all on function public.join_couple_v2(text) from public, anon;
grant execute on function public.join_couple_v2(text) to authenticated;

-- Keep installed versions working without requiring an app update.
create or replace function public.join_couple(invite text) returns uuid
language sql security definer set search_path = '' as $$
  select (private.try_join_space(invite)->>'space_id')::uuid;
$$;
revoke all on function public.join_couple(text) from public, anon;
grant execute on function public.join_couple(text) to authenticated;
