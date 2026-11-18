alter table public.date_invitations drop constraint date_invitations_status_check;
alter table public.date_invitations add constraint date_invitations_status_check check(status in('pending','accepted','declined','cancelled','completed'));
alter table public.date_invitations drop constraint date_invitations_address_check;
alter table public.date_invitations add constraint date_invitations_address_check check(length(address)<=300);
alter table public.date_invitations add column latitude double precision check(latitude between -90 and 90), add column longitude double precision check(longitude between -180 and 180), add column completed_at timestamptz, add column selfie_path text;
alter table public.date_invitations add constraint date_coordinates_pair check((latitude is null)=(longitude is null));
create index date_invitations_status_time on public.date_invitations(couple_id,status,starts_at,id);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('date-memories','date-memories',false,10485760,array['image/jpeg','image/png']) on conflict(id) do nothing;
create policy date_photo_read on storage.objects for select to authenticated using(bucket_id='date-memories' and exists(select 1 from public.date_invitations d where d.selfie_path=name and private.is_couple_member(d.couple_id)));
create policy date_photo_upload on storage.objects for insert to authenticated with check(bucket_id='date-memories' and exists(select 1 from public.date_invitations d where (storage.foldername(name))[1]=d.couple_id::text and (storage.foldername(name))[2]=d.id::text and (storage.foldername(name))[3]=(select auth.uid())::text and private.is_couple_member(d.couple_id) and d.status in('pending','accepted') and d.starts_at<=now()));
create policy date_photo_orphan_delete on storage.objects for delete to authenticated using(bucket_id='date-memories' and owner_id=(select auth.uid())::text and not exists(select 1 from public.date_invitations d where d.selfie_path=name));
create function public.complete_date(invitation_id uuid,photo_path text default null) returns void language plpgsql security definer set search_path='' as $$
declare d public.date_invitations;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into d from public.date_invitations where id=invitation_id for update;
 if d.id is null or not private.is_couple_member(d.couple_id) then raise exception 'Date unavailable'; end if;
 if d.status not in('pending','accepted') or d.starts_at>now() then raise exception 'This date cannot be completed yet'; end if;
 if photo_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='date-memories' and o.name=photo_path and o.owner_id=auth.uid()::text and (storage.foldername(o.name))[1]=d.couple_id::text and (storage.foldername(o.name))[2]=d.id::text and (storage.foldername(o.name))[3]=auth.uid()::text) then raise exception 'Photo unavailable'; end if;
 update public.date_invitations set status='completed',completed_at=now(),selfie_path=photo_path where id=invitation_id;
end $$;
revoke all on function public.complete_date(uuid,text) from public,anon;
grant execute on function public.complete_date(uuid,text) to authenticated;
-- Creator can also cancel an accepted date; partner responses remain pending-only.
create or replace function public.respond_to_date(invitation_id uuid,answer text) returns void language plpgsql security definer set search_path='' as $$
declare d public.date_invitations;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into d from public.date_invitations where id=invitation_id for update;
 if d.id is null or not private.is_couple_member(d.couple_id) then raise exception 'Invitation unavailable'; end if;
 if d.creator_id=auth.uid() and answer='cancelled' and d.status in('pending','accepted') then
  update public.date_invitations set status='cancelled' where id=invitation_id; return;
 end if;
 if d.creator_id=auth.uid() or answer not in('accepted','declined') or d.status<>'pending' or d.starts_at<=now() then raise exception 'Invalid invitation response'; end if;
 update public.date_invitations set status=answer where id=invitation_id;
end $$;

create table public.date_notifications(
 id uuid primary key default gen_random_uuid(),
 invitation_id uuid not null references public.date_invitations(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in('invitation','24h','6h','1h')),
 due_at timestamptz not null,
 delivered_at timestamptz,
 lease_until timestamptz,
 attempts integer not null default 0,
 unique(invitation_id,recipient_id,kind)
);
alter table public.date_notifications enable row level security;
revoke all on public.date_notifications from anon,authenticated;
grant all on public.date_notifications to service_role;
create index date_notification_due on public.date_notifications(due_at) where delivered_at is null;
create index date_notification_recipient on public.date_notifications(recipient_id);
create function private.queue_date_notifications() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  insert into public.date_notifications(invitation_id,recipient_id,kind,due_at)
  select new.id,p.id,'invitation',now() from public.profiles p where p.couple_id=new.couple_id and p.id<>new.creator_id;
  insert into public.date_notifications(invitation_id,recipient_id,kind,due_at)
  select new.id,p.id,t.kind,new.starts_at-t.offset_time from public.profiles p cross join(values('24h',interval '24 hours'),('6h',interval '6 hours'),('1h',interval '1 hour')) t(kind,offset_time)
  where p.couple_id=new.couple_id and new.starts_at-t.offset_time>now();
 elsif new.status in('cancelled','declined','completed') then
  delete from public.date_notifications where invitation_id=new.id and delivered_at is null;
 end if;
 return new;
end $$;
revoke all on function private.queue_date_notifications() from public,anon,authenticated;
create trigger queue_date_alerts after insert or update of status on public.date_invitations for each row execute function private.queue_date_notifications();
create function public.claim_date_notifications() returns setof public.date_notifications language sql security invoker set search_path='' as $$
 update public.date_notifications n set lease_until=now()+interval '2 minutes',attempts=attempts+1
 where n.id in(select q.id from public.date_notifications q join public.date_invitations d on d.id=q.invitation_id where q.delivered_at is null and q.due_at<=now() and q.due_at>now()-interval '1 hour' and q.attempts<10 and (q.lease_until is null or q.lease_until<now()) and d.status in('pending','accepted') and d.starts_at>now() order by q.due_at limit 30 for update of q skip locked) returning n.*;
$$;
revoke all on function public.claim_date_notifications() from public,anon,authenticated;
grant execute on function public.claim_date_notifications() to service_role;
create function private.dispatch_date_notifications() returns void language plpgsql security definer set search_path='' as $$
declare secret text;
begin
 select decrypted_secret into secret from vault.decrypted_secrets where name='jigu_notification_secret';
 if secret is null then return; end if;
 perform net.http_post(url:='https://dtjasplpglevmtagkrfp.supabase.co/functions/v1/notify-date',headers:=jsonb_build_object('content-type','application/json','x-jigu-notification-secret',secret),body:='{}'::jsonb);
end $$;
revoke all on function private.dispatch_date_notifications() from public,anon,authenticated;
create function private.wake_date_worker() returns trigger language plpgsql security definer set search_path='' as $$
begin perform private.dispatch_date_notifications(); return new; end $$;
revoke all on function private.wake_date_worker() from public,anon,authenticated;
create trigger dispatch_date_alert after insert on public.date_notifications for each statement execute function private.wake_date_worker();
select cron.schedule('jigu-date-reminders','* * * * *','select private.dispatch_date_notifications()');
-- Existing future dates receive future reminders, without resending invitations.
insert into public.date_notifications(invitation_id,recipient_id,kind,due_at)
select d.id,p.id,t.kind,d.starts_at-t.offset_time from public.date_invitations d join public.profiles p on p.couple_id=d.couple_id cross join(values('24h',interval '24 hours'),('6h',interval '6 hours'),('1h',interval '1 hour')) t(kind,offset_time)
where d.status in('pending','accepted') and d.starts_at-t.offset_time>now() on conflict do nothing;
drop policy dates_create on public.date_invitations;
create policy dates_create on public.date_invitations for insert to authenticated with check(private.is_couple_member(couple_id) and creator_id=(select auth.uid()) and status='pending' and completed_at is null and selfie_path is null and starts_at>now() and starts_at<now()+interval '3 years');
