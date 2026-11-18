begin;
do $$
declare first_id uuid := gen_random_uuid();
declare second_id uuid := gen_random_uuid();
declare code text;
declare couple uuid;
begin
  insert into auth.users(id, email) values
    (first_id, 'jigu-pair-a@example.invalid'),
    (second_id, 'jigu-pair-b@example.invalid');
  select invite_code into code from public.profiles where id = first_id;
  perform set_config('request.jwt.claim.sub', second_id::text, true);
  couple := public.join_couple(code);
  if not exists (
    select 1 from public.couples c
    join public.profiles a on a.id = first_id
    join public.profiles b on b.id = second_id
    where c.id = couple and c.person_a = first_id and c.person_b = second_id
      and a.couple_id = couple and b.couple_id = couple
  ) then
    raise exception 'Pairing failed';
  end if;
end $$;
rollback;
