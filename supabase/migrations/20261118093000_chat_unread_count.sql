create or replace function public.chat_unread_count(space uuid)
returns integer
language sql
stable
security invoker
set search_path = ''
as $$
  select count(*)::integer from (
    select 1
    from public.chat_messages m
    left join public.chat_state s
      on s.couple_id = space and s.user_id = (select auth.uid())
    where m.couple_id = space
      and m.sender_id <> (select auth.uid())
      and m.created_at > coalesce(s.read_at, '-infinity'::timestamptz)
      and private.is_couple_member(space)
    limit 100
  ) unread;
$$;
revoke all on function public.chat_unread_count(uuid) from public, anon;
grant execute on function public.chat_unread_count(uuid) to authenticated;
