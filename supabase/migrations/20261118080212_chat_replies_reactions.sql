begin;

alter table public.chat_messages
  add column reply_to_id uuid references public.chat_messages(id) on delete set null;
create index chat_messages_reply_to on public.chat_messages(reply_to_id)
  where reply_to_id is not null;

create or replace function private.validate_chat_reply() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.reply_to_id is not null and not exists (
    select 1 from public.chat_messages parent
    where parent.id = new.reply_to_id
      and parent.couple_id = new.couple_id
      and parent.created_at <= now()
  ) then
    raise exception 'Reply to a message in this conversation';
  end if;
  return new;
end $$;
revoke all on function private.validate_chat_reply() from public, anon, authenticated;
create trigger validate_chat_reply before insert on public.chat_messages
  for each row execute function private.validate_chat_reply();

create table public.chat_reactions (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  emoji text not null check (length(emoji) between 1 and 32 and emoji !~ '[[:cntrl:]]'),
  updated_at timestamptz not null default now(),
  primary key (message_id, user_id)
);
create index chat_reactions_user on public.chat_reactions(user_id);
alter table public.chat_reactions enable row level security;
grant select, insert, update(emoji), delete on public.chat_reactions to authenticated;
grant all on public.chat_reactions to service_role;
create policy chat_reactions_read on public.chat_reactions for select to authenticated
  using (exists (select 1 from public.chat_messages m where m.id = message_id
    and private.is_couple_member(m.couple_id)));
create policy chat_reactions_insert on public.chat_reactions for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.chat_messages m where m.id = message_id
      and private.is_couple_member(m.couple_id)));
create policy chat_reactions_update on public.chat_reactions for update to authenticated
  using (user_id = (select auth.uid()) and exists (
    select 1 from public.chat_messages m where m.id = message_id
      and private.is_couple_member(m.couple_id)))
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.chat_messages m where m.id = message_id
      and private.is_couple_member(m.couple_id)));
create policy chat_reactions_delete on public.chat_reactions for delete to authenticated
  using (user_id = (select auth.uid()));

alter publication supabase_realtime add table public.chat_reactions;
commit;
