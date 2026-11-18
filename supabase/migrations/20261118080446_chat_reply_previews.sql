begin;
alter table public.chat_messages add column reply_preview text,
  add column reply_sender_id uuid references auth.users(id) on delete set null;

create or replace function private.validate_chat_reply() returns trigger
language plpgsql set search_path = '' as $$
declare original public.chat_messages%rowtype;
begin
  new.reply_preview = null;
  new.reply_sender_id = null;
  if new.reply_to_id is not null then
    select * into original from public.chat_messages parent
      where parent.id = new.reply_to_id and parent.couple_id = new.couple_id;
    if not found then
      raise exception 'Reply to a message in this conversation';
    end if;
    new.reply_sender_id = original.sender_id;
    new.reply_preview = case when original.kind = 'text'
      then left(original.body, 120)
      else case original.kind when 'image' then 'Photo'
        when 'video' then 'Video' when 'voice' then 'Voice message'
        else 'GIF' end end;
  end if;
  return new;
end $$;
commit;
