begin;
insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','chat-a@example.invalid'),
 ('a1000000-0000-4000-8000-000000000002','chat-b@example.invalid'),
 ('a1000000-0000-4000-8000-000000000003','chat-outsider@example.invalid');
insert into public.couples(id,person_a,person_b) values('b1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
update public.profiles set couple_id='b1000000-0000-4000-8000-000000000001' where id in('a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
insert into public.mood_journal_entries(user_id,entry_date,mood,journal) values(auth.uid(),current_date,'loved','Private QA note');
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.mood_journal_entries) then raise exception 'Private reflection leaked';end if;end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
insert into public.reflection_sharing values(auth.uid(),'b1000000-0000-4000-8000-000000000001',true);
insert into public.chat_preferences values('b1000000-0000-4000-8000-000000000001','ocean');
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000002',true);
do $$ declare affected int; begin
 if (select count(*) from public.mood_journal_entries)<>1 then raise exception 'Partner cannot read shared reflection';end if;
 update public.mood_journal_entries set journal='changed';get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Partner edited author journal';end if;
 delete from public.mood_journal_entries;get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Partner deleted author journal';end if;
end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000003',true);
do $$ begin if exists(select 1 from public.mood_journal_entries) then raise exception 'Outsider read shared reflection';end if;end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
update public.reflection_sharing set enabled=false where user_id=auth.uid();
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000002',true);
do $$ begin if exists(select 1 from public.mood_journal_entries) then raise exception 'Revoked reflection leaked';end if;end $$;
reset role;
update public.reflection_sharing set enabled=true;
update public.profiles set couple_id=null where id='a1000000-0000-4000-8000-000000000002';
do $$ begin if exists(select 1 from public.reflection_sharing where couple_id='b1000000-0000-4000-8000-000000000001') then raise exception 'Consent survived leaving';end if;end $$;
rollback;
