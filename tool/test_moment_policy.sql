begin;
do $test$
declare a uuid; b uuid; c uuid; m uuid; path text; current_count integer;
begin
  select id,person_a,person_b into c,a,b from public.couples where person_b is not null limit 1;
  if c is null then raise exception 'Test requires a paired couple'; end if;
  select count(*) into current_count from public.moments where couple_id=c and created_at>now()-interval '24 hours';
  if current_count >= 24 then raise exception 'Quota full; cannot run isolated policy check'; end if;
  path := c::text || '/policy-check-' || gen_random_uuid()::text || '.jpg';
  perform set_config('request.jwt.claim.sub',a::text,true);
  execute 'set local role authenticated';
  if auth.uid() is distinct from a then raise exception 'JWT user context was not established'; end if;
  if not private.is_couple_member(c) then raise exception 'Paired user was not recognized as member'; end if;
  insert into public.moments(couple_id,author_id,storage_path) values(c,a,path);
  select id into m from public.moments where storage_path=path;
  if m is null then raise exception 'Inserted moment was not visible'; end if;
  perform set_config('request.jwt.claim.sub',b::text,true);
  insert into public.moment_likes(moment_id,user_id) values(m,b);
  update public.couples set started_on=date '2024-01-01' where id=c;
  if not found then raise exception 'Partner could not set relationship date'; end if;
  perform set_config('request.jwt.claim.sub',a::text,true);
  update public.moments set deleted_at=now() where id=m;
  if not found then raise exception 'Author could not remove moment'; end if;
  if private.can_read_moment(m) then raise exception 'Deleted unliked moment visible to author'; end if;
  perform set_config('request.jwt.claim.sub',b::text,true);
  if not private.can_read_moment(m) then raise exception 'Saved favorite disappeared after deletion'; end if;
  delete from public.moment_likes where moment_id=m and user_id=b;
  if private.can_read_moment(m) then raise exception 'Removed favorite remained visible'; end if;
end $test$;
reset role;
do $quota$
declare a uuid; c uuid; used integer; i integer; blocked boolean:=false;
begin
  select couple_id,id into c,a from public.profiles where couple_id is not null limit 1;
  select count(*) into used from public.moments where couple_id=c and created_at>now()-interval '24 hours';
  if used >= 24 then raise exception 'Quota test needs an available slot'; end if;
  perform set_config('request.jwt.claim.sub',a::text,true);
  execute 'set local role authenticated';
  for i in 1..(24-used) loop
    insert into public.moments(couple_id,author_id,storage_path)
    values(c,a,c::text || '/quota-check-' || gen_random_uuid()::text || '.jpg');
  end loop;
  begin
    insert into public.moments(couple_id,author_id,storage_path)
    values(c,a,c::text || '/quota-check-extra-' || gen_random_uuid()::text || '.jpg');
  exception when others then
    blocked := position('24 photos' in sqlerrm)>0;
  end;
  if not blocked then raise exception 'Rolling quota did not reject the 25th upload'; end if;
end $quota$;
rollback;
