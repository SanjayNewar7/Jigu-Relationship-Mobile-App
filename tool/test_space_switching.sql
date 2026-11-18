-- Synthetic users only; every change is rolled back.
begin;
do $test$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid();
  acode text; bcode text; ccode text; ab uuid; ac uuid; response jsonb; i integer;
begin
  insert into auth.users(id, email) values
    (a, a::text || '@example.invalid'), (b, b::text || '@example.invalid'),
    (c, c::text || '@example.invalid');
  select invite_code into acode from public.profiles where id=a;
  select invite_code into bcode from public.profiles where id=b;
  select invite_code into ccode from public.profiles where id=c;
  perform set_config('request.jwt.claim.sub', a::text, true);
  execute 'set local role authenticated';
  ab := public.join_couple(bcode);
  if ab is null then raise exception 'Initial pairing failed'; end if;
  perform public.leave_couple();
  if exists(select 1 from public.couples where id=ab) then raise exception 'Left space still visible'; end if;
  response := public.join_couple_v2(ccode);
  if response->>'status' <> 'joined' then raise exception 'Switch failed: %', response; end if;
  ac := (response->>'space_id')::uuid;
  if ac=ab then raise exception 'New partner inherited old space'; end if;
  if exists(select 1 from public.couples where id=ab) then raise exception 'Old history leaked'; end if;
  perform public.leave_couple();
  if public.join_couple(bcode) is distinct from ab then raise exception 'Original space not restored'; end if;
  perform set_config('request.jwt.claim.sub', c::text, true);
  if exists(select 1 from public.couples where id=ab) then raise exception 'Third person reads old pair'; end if;
  perform public.leave_couple();
  response := public.join_couple_v2(bcode);
  if response->>'status' <> 'target_unavailable' then raise exception 'Occupied target accepted'; end if;
  response := public.join_couple_v2(ccode);
  if response->>'status' <> 'own_code' then raise exception 'Own code accepted'; end if;
  for i in 1..3 loop
    response := public.join_couple_v2('bad');
    if response->>'status' <> 'invalid_code' then raise exception 'Malformed code accepted'; end if;
  end loop;
  response := public.join_couple_v2(acode);
  if response->>'status' <> 'rate_limited' then raise exception 'Attempt limit missing'; end if;
  execute 'reset role';
  update private.pair_attempts set window_started=now()-interval '11 minutes' where user_id=c;
  perform set_config('request.jwt.claim.sub', a::text, true);
  execute 'set local role authenticated';
  perform public.leave_couple();
  perform set_config('request.jwt.claim.sub', c::text, true);
  if public.join_couple(acode) is distinct from ac then raise exception 'Historical pair not restored'; end if;
  -- A deliberately remains outside until they rejoin themselves.
  perform set_config('request.jwt.claim.sub', a::text, true);
  if exists(select 1 from public.couples where id=ac) then raise exception 'Left partner silently restored'; end if;
  if public.join_couple(ccode) is distinct from ac then raise exception 'Second partner rejoin failed'; end if;
  if exists(select 1 from public.profiles where id=a and location_enabled) then raise exception 'Location enabled without consent'; end if;
  -- Successful joins must not exhaust the failed-code allowance.
  for i in 1..6 loop
    perform public.leave_couple();
    if public.join_couple(ccode) is distinct from ac then raise exception 'Successful joins throttled'; end if;
  end loop;
  execute 'reset role';
  if has_function_privilege('anon', 'public.join_couple_v2(text)', 'execute') then raise exception 'Anonymous access'; end if;
  if has_function_privilege('authenticated', 'private.try_join_space(text)', 'execute') then raise exception 'Private helper exposed'; end if;
end $test$;
reset role;
select 'PASS: switch, rejoin, privacy, consent, code errors, throttling, legacy RPC' as result;
rollback;
