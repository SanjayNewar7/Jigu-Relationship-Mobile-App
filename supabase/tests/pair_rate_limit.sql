begin;
do $$
declare first_id uuid := gen_random_uuid();
declare second_id uuid := gen_random_uuid();
declare code text;
declare wrong_code text;
begin
  insert into auth.users(id, email) values
    (first_id, 'jigu-limit-a@example.invalid'),
    (second_id, 'jigu-limit-b@example.invalid');
  select invite_code into code from public.profiles where id = first_id;
  wrong_code := case when code = '999999' then '888888' else '999999' end;
  perform set_config('request.jwt.claim.sub', second_id::text, true);
  for i in 1..5 loop
    if public.join_couple(wrong_code) is not null then
      raise exception 'Invalid code accepted';
    end if;
  end loop;
  if public.join_couple(code) is not null then
    raise exception 'Sixth attempt bypassed rate limit';
  end if;
  if (select attempts from private.pair_attempts where user_id = second_id) <> 6 then
    raise exception 'Attempt count did not persist';
  end if;
end $$;
rollback;
