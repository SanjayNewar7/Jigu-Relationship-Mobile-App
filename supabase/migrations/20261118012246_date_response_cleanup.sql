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
  if new.status in('cancelled','completed') then
   delete from public.date_notifications
   where invitation_id=new.id and delivered_at is null;
  elsif new.status='declined' then
   delete from public.date_notifications
   where invitation_id=new.id and delivered_at is null and kind<>'declined';
  end if;
 end if;
 return new;
end $$;
