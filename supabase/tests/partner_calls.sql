begin;
insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','chat-a@example.invalid'),
 ('a1000000-0000-4000-8000-000000000002','chat-b@example.invalid'),
 ('a1000000-0000-4000-8000-000000000003','chat-outsider@example.invalid');
insert into public.couples(id,person_a,person_b) values('b1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
update public.profiles set couple_id='b1000000-0000-4000-8000-000000000001' where id in('a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
set local role service_role;
select public.manage_partner_call('a1000000-0000-4000-8000-000000000001','start',null,'audio');
do $$ declare c public.partner_calls; begin
 select * into c from public.partner_calls where couple_id='b1000000-0000-4000-8000-000000000001';
 begin
 perform public.manage_partner_call('a1000000-0000-4000-8000-000000000002','start',null,'audio');
 raise exception 'Concurrent call was accepted';
 exception when raise_exception then if sqlerrm<>'A call is already in progress' then raise;end if;end;
 c=public.manage_partner_call(c.caller_id,'accept',c.id);if c.status<>'ringing' then raise exception 'Caller accepted own call';end if;
 c=public.manage_partner_call(c.callee_id,'accept',c.id);if c.status<>'accepted' then raise exception 'Callee acceptance failed';end if;
 c=public.manage_partner_call(c.caller_id,'end',c.id);if c.status<>'ended' then raise exception 'Hangup failed';end if;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000003',true);
do $$ begin
 if exists(select 1 from public.partner_calls) then raise exception 'Outsider reads call history';end if;
 begin perform public.manage_partner_call('a1000000-0000-4000-8000-000000000001','start',null,'audio');raise exception 'Direct RPC bypass';exception when insufficient_privilege then null;end;
end $$;
reset role;
update public.partner_calls set status='ringing',created_at=now()-interval '60 seconds';
select public.expire_partner_calls();
do $$ begin if exists(select 1 from public.partner_calls where status<>'missed') then raise exception 'Call timeout failed';end if;end $$;
update public.partner_calls set status='accepted',accepted_at=now();
update public.profiles set couple_id=null where id='a1000000-0000-4000-8000-000000000002';
do $$ begin if exists(select 1 from public.partner_calls where status<>'ended') then raise exception 'Call survived space departure';end if;end $$;
rollback;
