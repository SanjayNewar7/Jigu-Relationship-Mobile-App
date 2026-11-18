begin;
insert into auth.users(id,email) values
 ('c1000000-0000-4000-8000-000000000001','date-response-a@example.invalid'),
 ('c1000000-0000-4000-8000-000000000002','date-response-b@example.invalid');
insert into public.couples(id,person_a,person_b) values
 ('d1000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000002');
update public.profiles set couple_id='d1000000-0000-4000-8000-000000000001'
where id in('c1000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
insert into public.date_invitations(id,couple_id,creator_id,starts_at,venue,address,dress_style)
values
 ('e1000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001',now()+interval '2 days','QA place','QA address','Casual'),
 ('e1000000-0000-4000-8000-000000000002','d1000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001',now()+interval '3 days','QA place','QA address','Casual');
select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000002',true);
select public.respond_to_date('e1000000-0000-4000-8000-000000000001','accepted');
select public.respond_to_date('e1000000-0000-4000-8000-000000000002','declined');
reset role;
do $$ begin
 if not exists(select 1 from public.date_notifications where invitation_id='e1000000-0000-4000-8000-000000000001' and kind='accepted' and recipient_id='c1000000-0000-4000-8000-000000000001') then
  raise exception 'Accepted reply did not notify creator';
 end if;
 if not exists(select 1 from public.date_notifications where invitation_id='e1000000-0000-4000-8000-000000000002' and kind='declined' and recipient_id='c1000000-0000-4000-8000-000000000001') then
  raise exception 'Declined reply did not notify creator';
 end if;
 if exists(select 1 from public.date_notifications where invitation_id='e1000000-0000-4000-8000-000000000002' and kind in('24h','6h','1h') and delivered_at is null) then
  raise exception 'Declined date retained reminders';
 end if;
end $$;
rollback;
