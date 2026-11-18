begin;
do $test$
declare a uuid; b uuid; c uuid; code text; m uuid; joined uuid;
begin
 select id,person_a,person_b into c,a,b from public.couples where person_b is not null limit 1;
 if c is null then raise exception 'Paired test account required'; end if;
 select invite_code into code from public.profiles where id=b;
 delete from private.pair_attempts where user_id=a;
 perform set_config('request.jwt.claim.sub',a::text,true);
 execute 'set local role authenticated';
 perform public.leave_couple();
 if private.is_couple_member(c) then raise exception 'Left member retained access'; end if;
 if exists(select 1 from public.couples where id=c) then raise exception 'Left member reads space'; end if;
 if exists(select 1 from public.moments where couple_id=c) then raise exception 'Left member reads photos'; end if;
 joined:=public.join_couple(code);
 if joined is distinct from c then raise exception 'Rejoin created wrong space'; end if;
 if not private.is_couple_member(c) then raise exception 'Rejoin did not restore access'; end if;
 if exists(select 1 from public.profiles where id=a and location_enabled) then raise exception 'Rejoin silently enabled location'; end if;
 m:=gen_random_uuid();
 insert into public.moments(id,couple_id,author_id,storage_path) values(m,c,a,c::text||'/notification-policy-'||m||'.jpg');
 if exists(select 1 from public.moment_notifications where moment_id=m) then raise exception 'Sender can read recipient queue'; end if;
 perform set_config('request.jwt.claim.sub',b::text,true);
 if not exists(select 1 from public.moment_notifications where moment_id=m and recipient_id=b) then raise exception 'Partner alert not queued'; end if;
 perform public.leave_couple();
 if exists(select 1 from public.moment_notifications where moment_id=m) then raise exception 'Left partner can read alert'; end if;
end $test$;
reset role;
rollback;
