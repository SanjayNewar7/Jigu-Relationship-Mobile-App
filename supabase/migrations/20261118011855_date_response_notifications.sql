alter table public.date_notifications drop constraint date_notifications_kind_check;
alter table public.date_notifications add constraint date_notifications_kind_check
 check(kind in('invitation','24h','6h','1h','accepted','declined'));

create or replace function private.queue_date_notifications() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  insert into public.date_notifications(invitation_id,recipient_id,kind,due_at)
  select new.id,p.id,'invitation',now() from public.profiles p
  where p.couple_id=new.couple_id and p.id<>new.creator_id;
  insert into public.date_notifications(invitation_id,recipient_id,kind,due_at)
  select new.id,p.id,t.kind,new.starts_at-t.offset_time
  from public.profiles p cross join(values('24h',interval '24 hours'),('6h',interval '6 hours'),('1h',interval '1 hour')) t(kind,offset_time)
  where p.couple_id=new.couple_id and new.starts_at-t.offset_time>now();
 elsif new.status is distinct from old.status then
  if new.status in('accepted','declined') then
   insert into public.date_notifications(invitation_id,recipient_id,kind,due_at)
   values(new.id,new.creator_id,new.status,now()) on conflict do nothing;
  end if;
  if new.status in('cancelled','declined','completed') then
   delete from public.date_notifications
   where invitation_id=new.id and delivered_at is null and kind not in('accepted','declined');
  end if;
 end if;
 return new;
end $$;

create or replace function public.claim_date_notifications() returns setof public.date_notifications
language sql security invoker set search_path='' as $$
 update public.date_notifications n set lease_until=now()+interval '2 minutes',attempts=attempts+1
 where n.id in(
  select q.id from public.date_notifications q
  join public.date_invitations d on d.id=q.invitation_id
  where q.delivered_at is null and q.due_at<=now() and q.due_at>now()-interval '1 hour'
   and q.attempts<10 and (q.lease_until is null or q.lease_until<now())
   and ((q.kind in('accepted','declined') and d.status=q.kind)
     or (q.kind not in('accepted','declined') and d.status in('pending','accepted') and d.starts_at>now()))
  order by q.due_at limit 30 for update of q skip locked
 ) returning n.*;
$$;
