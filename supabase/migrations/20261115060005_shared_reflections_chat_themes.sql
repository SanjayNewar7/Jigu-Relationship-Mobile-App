begin;
alter table public.chat_preferences drop constraint chat_preferences_theme_check;
alter table public.chat_preferences add constraint chat_preferences_theme_check check(theme in ('lily','sage','midnight','rose','ocean','lavender','sunset','cocoa'));
create table public.reflection_sharing (
 user_id uuid primary key references auth.users(id) on delete cascade,
 couple_id uuid not null references public.couples(id) on delete cascade,
 enabled boolean not null default false
);
create index reflection_sharing_couple on public.reflection_sharing(couple_id);
alter table public.reflection_sharing enable row level security;
grant select,insert,update,delete on public.reflection_sharing to authenticated;
create policy reflection_sharing_read on public.reflection_sharing for select to authenticated using(user_id=(select auth.uid()) or private.is_couple_member(couple_id));
create policy reflection_sharing_write on public.reflection_sharing for insert to authenticated with check(user_id=(select auth.uid()) and private.is_couple_member(couple_id));
create policy reflection_sharing_update on public.reflection_sharing for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()) and private.is_couple_member(couple_id));
create policy reflection_sharing_delete on public.reflection_sharing for delete to authenticated using(user_id=(select auth.uid()));
create policy mood_journal_partner_read on public.mood_journal_entries for select to authenticated using(exists(
 select 1 from public.reflection_sharing s join public.profiles p on p.id=s.user_id
 where s.user_id=mood_journal_entries.user_id and s.enabled and p.couple_id=s.couple_id and private.is_couple_member(s.couple_id)
));
-- Disable consent when either membership changes; it never carries to a new space.
create function private.reset_reflection_sharing() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.couple_id is distinct from new.couple_id then
 delete from public.reflection_sharing where user_id=new.id or couple_id=old.couple_id;
 end if;
 return new;
end $$;
create trigger reset_reflection_sharing after update of couple_id on public.profiles for each row execute function private.reset_reflection_sharing();
commit;
