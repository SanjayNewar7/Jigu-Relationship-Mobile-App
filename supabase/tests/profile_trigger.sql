begin;
do $$
declare test_id uuid := gen_random_uuid();
begin
  insert into auth.users(id, email) values (test_id, 'jigu-trigger-test@example.invalid');
  if not exists (select 1 from public.profiles where id = test_id and invite_code ~ '^[0-9]{6}$') then
    raise exception 'Profile trigger failed';
  end if;
end $$;
rollback;
