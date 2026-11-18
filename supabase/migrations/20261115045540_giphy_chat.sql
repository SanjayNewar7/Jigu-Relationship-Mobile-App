begin;
alter table public.chat_messages add column giphy_id text check(giphy_id ~ '^[a-zA-Z0-9]{1,100}$');
alter table public.chat_messages drop constraint chat_messages_check;
alter table public.chat_messages add constraint chat_message_content check(
 (kind='text' and length(trim(body))>0 and storage_path is null and giphy_id is null)
 or (kind<>'text' and storage_path is not null and giphy_id is null)
 or (kind='gif' and storage_path is null and giphy_id is not null));
create or replace function private.validate_chat_message() returns trigger language plpgsql set search_path='' as $$
begin
 new.created_at=now();new.media_deleted=false;
 new.expires_at=case when new.kind='text' then null else now()+interval '30 days' end;
 if new.storage_path is not null then
  if new.storage_path<>new.couple_id::text||'/'||new.sender_id::text||'/'||new.id::text then raise exception 'Invalid attachment path';end if;
  if not exists(select 1 from storage.objects where bucket_id='chat-media' and name=new.storage_path and owner_id=new.sender_id::text) then raise exception 'Upload the attachment first';end if;
 end if;
 return new;
end $$;
create function private.wake_chat_notifications() returns trigger language plpgsql security definer set search_path='' as $$
begin perform private.dispatch_chat_notifications();return null;end $$;
revoke all on function private.wake_chat_notifications() from public,anon,authenticated;
create trigger wake_chat_notifications after insert on public.chat_notifications for each statement execute function private.wake_chat_notifications();
create index chat_messages_sender on public.chat_messages(sender_id);
create index chat_state_user on public.chat_state(user_id);
commit;
