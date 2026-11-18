begin;
create table public.chat_user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade default auth.uid(),
  quick_reactions text[] not null default array['❤️','😂','😮','😢','😡','👍'],
  check(cardinality(quick_reactions)=6 and array_position(quick_reactions,'') is null),
  check(length(array_to_string(quick_reactions,''))<=192)
);
alter table public.chat_user_preferences enable row level security;
grant select,insert,update on public.chat_user_preferences to authenticated;
create policy reaction_preferences_owner on public.chat_user_preferences for all to authenticated
  using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
alter publication supabase_realtime add table public.chat_user_preferences;

alter table public.chat_messages add column deleted_at timestamptz,
  add column reply_kind text,
  add column reply_parent_deleted boolean not null default false;
alter table public.chat_messages drop constraint chat_message_content;
alter table public.chat_messages add constraint chat_message_content check (
  deleted_at is not null or
  (kind='text' and length(trim(body))>0 and storage_path is null and giphy_id is null) or
  (kind<>'text' and storage_path is not null and giphy_id is null) or
  (kind='gif' and storage_path is null and giphy_id is not null)
);
grant update(deleted_at) on public.chat_messages to authenticated;
create policy chat_unsend_owner on public.chat_messages for update to authenticated
  using(sender_id=(select auth.uid()) and private.is_couple_member(couple_id))
  with check(sender_id=(select auth.uid()) and private.is_couple_member(couple_id));

-- Internal trigger must redact cached replies written by either partner.
create function private.redact_unsent_chat() returns trigger language plpgsql
security definer set search_path='' as $$
begin
  if old.deleted_at is not null then new.deleted_at=old.deleted_at; return new; end if;
  if new.deleted_at is not null then
    if auth.uid() is distinct from old.sender_id then raise exception 'Only the sender can unsend'; end if;
    new.deleted_at=now(); new.body=''; new.giphy_id=null;
    new.media_deleted=true; new.expires_at=now();
    update public.chat_messages set reply_preview='Original message unavailable',reply_parent_deleted=true
      where reply_to_id=old.id;
    delete from public.chat_reactions where message_id=old.id;
  end if;
  return new;
end $$;
revoke all on function private.redact_unsent_chat() from public,anon,authenticated;
create trigger redact_unsent_chat before update of deleted_at on public.chat_messages
for each row execute function private.redact_unsent_chat();
grant update(message_id,user_id,emoji) on public.chat_reactions to authenticated;
create or replace function private.validate_chat_reply() returns trigger
language plpgsql set search_path='' as $$
declare original public.chat_messages%rowtype;
begin
  new.deleted_at=null; new.reply_parent_deleted=false;
  new.reply_preview=null; new.reply_sender_id=null; new.reply_kind=null;
  if new.reply_to_id is not null then
    select * into original from public.chat_messages where id=new.reply_to_id and couple_id=new.couple_id;
    if not found then raise exception 'Reply to a message in this conversation'; end if;
    new.reply_sender_id=original.sender_id;
    new.reply_kind=original.kind;
    new.reply_parent_deleted=original.deleted_at is not null;
    new.reply_preview=case when original.deleted_at is not null then 'Original message unavailable'
      when original.kind='text' then left(original.body,120)
      when original.kind='image' then 'Photo' when original.kind='video' then 'Video'
      when original.kind='voice' then 'Voice message' else 'GIF' end;
  end if;
  return new;
end $$;
create or replace function public.chat_unread_count(space uuid)
returns integer language sql stable security invoker set search_path='' as $$
  select count(*)::integer from (
    select 1 from public.chat_messages m left join public.chat_state s
      on s.couple_id=space and s.user_id=(select auth.uid())
    where m.couple_id=space and m.sender_id<>(select auth.uid()) and m.deleted_at is null
      and m.created_at>coalesce(s.read_at,'-infinity'::timestamptz)
      and private.is_couple_member(space) limit 100
  ) unread;
$$;
commit;
