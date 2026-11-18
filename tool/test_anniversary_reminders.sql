begin;
do $test$
declare c uuid;a uuid;target date;ann date;n integer;
begin
 if private.anniversary_day('2020-02-29',2025)<>'2025-02-28'::date or private.anniversary_day('2020-02-29',2028)<>'2028-02-29'::date then raise exception 'Leap anniversary incorrect'; end if;
 if (timestamp '2027-05-31 09:00'-interval '1 month')<>timestamp '2027-04-30 09:00' then raise exception 'Calendar month incorrect'; end if;
 select id,person_a into c,a from public.couples where person_b is not null limit 1;
 target:=((now() at time zone 'Asia/Kathmandu')::date+interval '2 months')::date;
 ann:=target;
 target:=make_date(extract(year from target)::integer-3,extract(month from target)::integer,extract(day from target)::integer);
 update public.couples set started_on=null where id=c;
 perform set_config('request.jwt.claim.sub',a::text,true);
 execute 'set local role authenticated';
 update public.couples set started_on=target where id=c;
 execute 'reset role';
 select count(*) into n from public.anniversary_notifications where couple_id=c and anniversary_date=ann;
 if n<>12 then raise exception 'Expected six reminders each, got %',n;end if;
 perform private.schedule_anniversaries(c);
 if (select count(*) from public.anniversary_notifications where couple_id=c and anniversary_date=ann)<>12 then raise exception 'Duplicate anniversary reminders';end if;
 if exists(select 1 from public.anniversary_notifications where couple_id=c and kind='24h' and due_at<>((anniversary_date+time '09:00')-interval '24 hours') at time zone 'Asia/Kathmandu') then raise exception 'Wrong local anniversary time';end if;
 update public.couples set started_on=null where id=c;
 if exists(select 1 from public.anniversary_notifications where couple_id=c) then raise exception 'Clearing relationship date retained countdowns';end if;
end $test$;
rollback;
