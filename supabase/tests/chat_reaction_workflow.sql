begin;
select set_config('request.jwt.claim.sub',(select sender_id::text from public.chat_messages where deleted_at is null limit 1),true);
set local role authenticated;
select set_config('jigu.test_parent',(select id::text from public.chat_messages where sender_id=auth.uid() and deleted_at is null limit 1),true);
select set_config('jigu.test_reply',gen_random_uuid()::text,true);
insert into public.chat_messages(id,couple_id,sender_id,kind,body,reply_to_id)
select current_setting('jigu.test_reply')::uuid,couple_id,auth.uid(),'text','Transactional test',id
from public.chat_messages where id=current_setting('jigu.test_parent')::uuid;
insert into public.chat_reactions(message_id,user_id,emoji)
values(current_setting('jigu.test_parent')::uuid,auth.uid(),'❤️')
on conflict(message_id,user_id) do update set emoji=excluded.emoji;
insert into public.chat_reactions(message_id,user_id,emoji)
values(current_setting('jigu.test_parent')::uuid,auth.uid(),'👍')
on conflict(message_id,user_id) do update set emoji=excluded.emoji;
insert into public.chat_user_preferences(user_id,quick_reactions)
values(auth.uid(),array['❤️','😂','😮','😢','😡','👍'])
on conflict(user_id) do update set quick_reactions=excluded.quick_reactions;
update public.chat_messages set deleted_at=now() where id=current_setting('jigu.test_parent')::uuid;
select
  (select body='' and deleted_at is not null from public.chat_messages where id=current_setting('jigu.test_parent')::uuid) as unsend_redacted,
  (select reply_parent_deleted and reply_preview='Original message unavailable' from public.chat_messages where id=current_setting('jigu.test_reply')::uuid) as quote_redacted,
  not exists(select 1 from public.chat_reactions where message_id=current_setting('jigu.test_parent')::uuid) as reactions_removed;
rollback;
