begin;
create table public.chat_messages (
 id uuid primary key,
 couple_id uuid not null references public.couples(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 kind text not null check(kind in ('text','image','video','voice','gif')),
 body text not null default '' check(length(body)<=4000),
 storage_path text unique,
 created_at timestamptz not null default now(),
 expires_at timestamptz,
 media_deleted boolean not null default false,
 check((kind='text' and length(trim(body))>0 and storage_path is null) or (kind<>'text' and storage_path is not null))
);
create index chat_messages_history on public.chat_messages(couple_id,created_at desc,id desc);
alter table public.chat_messages enable row level security;
grant select,insert on public.chat_messages to authenticated;
grant all on public.chat_messages to service_role;
create policy chat_read on public.chat_messages for select to authenticated using(private.is_couple_member(couple_id));
create policy chat_send on public.chat_messages for insert to authenticated with check(sender_id=(select auth.uid()) and private.is_couple_member(couple_id));
create function private.validate_chat_message() returns trigger language plpgsql set search_path='' as $$
begin
 new.created_at=now(); new.media_deleted=false;
 new.expires_at=case when new.kind='text' then null else now()+interval '30 days' end;
 if new.kind<>'text' then
   if new.storage_path<>new.couple_id::text||'/'||new.sender_id::text||'/'||new.id::text then raise exception 'Invalid attachment path'; end if;
   if not exists(select 1 from storage.objects where bucket_id='chat-media' and name=new.storage_path and owner_id=new.sender_id::text) then raise exception 'Upload the attachment first'; end if;
 end if;
 return new;
end $$;
revoke all on function private.validate_chat_message() from public,anon,authenticated;
create trigger validate_chat before insert on public.chat_messages for each row execute function private.validate_chat_message();

create table public.chat_state (
 couple_id uuid not null references public.couples(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 last_seen_at timestamptz not null default now(),
 read_at timestamptz not null default now(),
 typing_until timestamptz not null default now(),
 primary key(couple_id,user_id)
);
alter table public.chat_state enable row level security;
grant select,insert,update on public.chat_state to authenticated;
create policy chat_state_read on public.chat_state for select to authenticated using(private.is_couple_member(couple_id));
create policy chat_state_insert on public.chat_state for insert to authenticated with check(user_id=(select auth.uid()) and private.is_couple_member(couple_id));
create policy chat_state_update on public.chat_state for update to authenticated using(user_id=(select auth.uid()) and private.is_couple_member(couple_id)) with check(user_id=(select auth.uid()) and private.is_couple_member(couple_id));
create function public.touch_chat(space uuid, typing boolean default false) returns void language sql security invoker set search_path='' as $$
 insert into public.chat_state(couple_id,user_id,last_seen_at,read_at,typing_until)
 values(space,auth.uid(),now(),now(),case when typing then now()+interval '5 seconds' else now() end)
 on conflict(couple_id,user_id) do update set last_seen_at=now(),read_at=now(),typing_until=excluded.typing_until;
$$;
revoke all on function public.touch_chat(uuid,boolean) from public,anon;
grant execute on function public.touch_chat(uuid,boolean) to authenticated;

create table public.chat_preferences (
 couple_id uuid primary key references public.couples(id) on delete cascade,
 theme text not null default 'lily' check(theme in ('lily','sage','midnight'))
);
alter table public.chat_preferences enable row level security;
grant select,insert,update on public.chat_preferences to authenticated;
create policy chat_preferences_read on public.chat_preferences for select to authenticated using(private.is_couple_member(couple_id));
create policy chat_preferences_insert on public.chat_preferences for insert to authenticated with check(private.is_couple_member(couple_id));
create policy chat_preferences_update on public.chat_preferences for update to authenticated using(private.is_couple_member(couple_id)) with check(private.is_couple_member(couple_id));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('chat-media','chat-media',false,26214400,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','audio/mp4','audio/aac']);
create policy chat_upload on storage.objects for insert to authenticated with check(bucket_id='chat-media' and (storage.foldername(name))[2]=(select auth.uid())::text and exists(select 1 from public.profiles where id=(select auth.uid()) and couple_id::text=(storage.foldername(name))[1]));
create policy chat_download on storage.objects for select to authenticated using(bucket_id='chat-media' and created_at>now()-interval '30 days' and exists(select 1 from public.profiles where id=(select auth.uid()) and couple_id::text=(storage.foldername(name))[1]));
create policy chat_upload_cancel on storage.objects for delete to authenticated using(bucket_id='chat-media' and owner_id=(select auth.uid())::text and not exists(select 1 from public.chat_messages where storage_path=name));

create function public.pending_chat_cleanup() returns table(storage_path text) language sql security definer set search_path='' as $$
 select o.name from storage.objects o where o.bucket_id='chat-media' and (o.created_at<now()-interval '30 days' or (o.created_at<now()-interval '1 day' and not exists(select 1 from public.chat_messages m where m.storage_path=o.name))) limit 100;
$$;
revoke all on function public.pending_chat_cleanup() from public,anon,authenticated;
grant execute on function public.pending_chat_cleanup() to service_role;
create function public.complete_chat_cleanup(paths text[]) returns void language sql security invoker set search_path='' as $$
 update public.chat_messages set media_deleted=true where storage_path=any(paths) and expires_at<=now();
$$;
revoke all on function public.complete_chat_cleanup(text[]) from public,anon,authenticated;
grant execute on function public.complete_chat_cleanup(text[]) to service_role;
select cron.schedule('jigu-chat-cleanup','17 * * * *',$job$
 select net.http_post(url:='https://dtjasplpglevmtagkrfp.supabase.co/functions/v1/cleanup-chat',headers:=jsonb_build_object('content-type','application/json','x-jigu-cleanup-secret',(select decrypted_secret from vault.decrypted_secrets where name='jigu_cleanup_secret')),body:='{}'::jsonb);
$job$);

create table public.chat_notifications (
 id uuid primary key default gen_random_uuid(),
 message_id uuid not null references public.chat_messages(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 delivered_at timestamptz,
 attempts integer not null default 0,
 lease_until timestamptz,
 created_at timestamptz not null default now(),
 unique(message_id,recipient_id)
);
alter table public.chat_notifications enable row level security;
grant all on public.chat_notifications to service_role;
create index chat_notifications_pending on public.chat_notifications(created_at) where delivered_at is null;
create index chat_notifications_recipient on public.chat_notifications(recipient_id);
create function private.queue_chat_notification() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.chat_notifications(message_id,recipient_id) select new.id,id from public.profiles where couple_id=new.couple_id and id<>new.sender_id;
 return new;
end $$;
revoke all on function private.queue_chat_notification() from public,anon,authenticated;
create trigger chat_notification after insert on public.chat_messages for each row execute function private.queue_chat_notification();
create function public.claim_chat_notifications() returns setof public.chat_notifications language sql security invoker set search_path='' as $$
 update public.chat_notifications set lease_until=now()+interval '2 minutes',attempts=attempts+1 where id in(select id from public.chat_notifications where delivered_at is null and attempts<10 and created_at>now()-interval '1 day' and (lease_until is null or lease_until<now()) order by created_at limit 30 for update skip locked) returning *;
$$;
revoke all on function public.claim_chat_notifications() from public,anon,authenticated;
grant execute on function public.claim_chat_notifications() to service_role;
create function private.dispatch_chat_notifications() returns void language sql security definer set search_path='' as $$
 select net.http_post(url:='https://dtjasplpglevmtagkrfp.supabase.co/functions/v1/notify-chat',headers:=jsonb_build_object('content-type','application/json','x-jigu-notification-secret',(select decrypted_secret from vault.decrypted_secrets where name='jigu_notification_secret')),body:='{}'::jsonb);
$$;
revoke all on function private.dispatch_chat_notifications() from public,anon,authenticated;
select cron.schedule('jigu-chat-notifications','* * * * *','select private.dispatch_chat_notifications()');

alter publication supabase_realtime add table public.chat_messages,public.chat_state,public.chat_preferences;
create or replace function public.account_deletion_assets(target_user uuid) returns table(bucket_id text,object_name text) language sql security definer set search_path='' as $$
 select o.bucket_id,o.name from storage.objects o where o.bucket_id in ('moments','date-memories','chat-media') and (o.owner_id=target_user::text or exists(select 1 from public.couples c where target_user in(c.person_a,c.person_b) and o.name like c.id::text||'/%'));
$$;
commit;
