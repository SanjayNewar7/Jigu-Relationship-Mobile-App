begin;
do $test$
declare a uuid; b uuid; c uuid; invite uuid:=gen_random_uuid(); blocked boolean:=false;
begin
 select id,person_a,person_b into c,a,b from public.couples where person_b is not null limit 1;
 if c is null then raise exception 'Test needs a pair'; end if;
 perform set_config('request.jwt.claim.sub',a::text,true);
 execute 'set local role authenticated';
 insert into public.date_invitations(id,couple_id,creator_id,starts_at,venue,address,dress_style) values(invite,c,a,now()+interval '2 days','QA venue','QA address','Casual');
 begin perform public.respond_to_date(invite,'accepted'); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Creator accepted own invitation'; end if;
 perform set_config('request.jwt.claim.sub',b::text,true);
 if not exists(select 1 from public.date_invitations where id=invite) then raise exception 'Partner cannot read'; end if;
 perform public.respond_to_date(invite,'accepted');
 if not exists(select 1 from public.date_invitations where id=invite and status='accepted') then raise exception 'Response not saved'; end if;
 perform public.leave_couple();
 if exists(select 1 from public.date_invitations where id=invite) then raise exception 'Left member still reads invitation'; end if;
 blocked:=false;
 begin perform public.respond_to_date(invite,'declined'); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Left member could respond'; end if;
end $test$;
reset role;
rollback;
