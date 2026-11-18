begin;
insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','chat-a@example.invalid'),
 ('a1000000-0000-4000-8000-000000000002','chat-b@example.invalid'),
 ('a1000000-0000-4000-8000-000000000003','chat-outsider@example.invalid');
insert into public.couples(id,person_a,person_b) values('b1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
update public.profiles set couple_id='b1000000-0000-4000-8000-000000000001' where id in('a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
insert into public.chat_messages(id,couple_id,kind,body,created_at,expires_at) values('c1000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','text','hello','2000-01-01','2099-01-01');
select public.touch_chat('b1000000-0000-4000-8000-000000000001',true);
do $$ begin
 if not exists(select 1 from public.chat_messages where body='hello' and created_at>now()-interval '1 minute' and expires_at is null) then raise exception 'Server timestamps failed';end if;
 begin
  insert into public.chat_messages(id,couple_id,sender_id,kind,body) values(gen_random_uuid(),'b1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','text','forged');
  raise exception 'Forged sender accepted';
 exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000002',true);
do $$ begin if (select count(*) from public.chat_messages where couple_id='b1000000-0000-4000-8000-000000000001')<>1 then raise exception 'Partner cannot read';end if;end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000003',true);
do $$ begin
 if exists(select 1 from public.chat_messages) then raise exception 'Outsider can read';end if;
 begin
  insert into public.chat_messages(id,couple_id,kind,body) values(gen_random_uuid(),'b1000000-0000-4000-8000-000000000001','text','intrusion');
  raise exception 'Outsider can send';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
update public.profiles set couple_id=null where id='a1000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.chat_messages) then raise exception 'Departed member can read';end if;end $$;
rollback;
