create table public.date_invitations (
 id uuid primary key default gen_random_uuid(),
 couple_id uuid not null references public.couples(id) on delete cascade,
 creator_id uuid not null references auth.users(id) on delete cascade,
 starts_at timestamptz not null,
 venue text not null check(length(trim(venue)) between 1 and 160),
 address text not null check(length(trim(address)) between 1 and 300),
 dress_style text not null check(length(dress_style) between 1 and 100),
 message text not null default '' check(length(message)<=1200),
 status text not null default 'pending' check(status in('pending','accepted','declined','cancelled')),
 created_at timestamptz not null default now()
);
create index date_invitations_couple_time on public.date_invitations(couple_id,starts_at desc);
create index date_invitations_creator on public.date_invitations(creator_id);
alter table public.date_invitations enable row level security;
revoke all on public.date_invitations from anon,authenticated;
grant select,insert on public.date_invitations to authenticated;
create policy dates_read on public.date_invitations for select to authenticated using(private.is_couple_member(couple_id));
create policy dates_create on public.date_invitations for insert to authenticated with check(private.is_couple_member(couple_id) and creator_id=(select auth.uid()) and status='pending' and starts_at>now() and starts_at<now()+interval '3 years');
-- Response is a narrow operation: clients cannot rewrite ownership or invitation details.
create function public.respond_to_date(invitation_id uuid,answer text) returns void
language plpgsql security definer set search_path='' as $$
declare invitation public.date_invitations;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into invitation from public.date_invitations where id=invitation_id for update;
 if invitation.id is null or not private.is_couple_member(invitation.couple_id) then raise exception 'Invitation unavailable'; end if;
 if invitation.status<>'pending' then raise exception 'Invitation already answered'; end if;
 if invitation.creator_id=auth.uid() then
   if answer<>'cancelled' then raise exception 'Only your partner may accept'; end if;
 else
   if answer not in('accepted','declined') then raise exception 'Invalid response'; end if;
   if invitation.starts_at<=now() then raise exception 'This date has passed'; end if;
 end if;
 update public.date_invitations set status=answer where id=invitation_id;
end $$;
revoke all on function public.respond_to_date(uuid,text) from public,anon;
grant execute on function public.respond_to_date(uuid,text) to authenticated;
alter publication supabase_realtime add table public.date_invitations;
