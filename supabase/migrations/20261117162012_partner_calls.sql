begin;
create table public.partner_calls (
 id uuid primary key default gen_random_uuid(),
 couple_id uuid not null references public.couples(id) on delete cascade,
 caller_id uuid not null references auth.users(id) on delete cascade,
 callee_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('audio','video')),
 status text not null default 'ringing' check(status in ('ringing','accepted','declined','ended','missed')),
 created_at timestamptz not null default now(),
 accepted_at timestamptz, ended_at timestamptz,
 caller_seen timestamptz not null default now(), callee_seen timestamptz not null default now(),
 media_closed boolean not null default false,
 check(caller_id<>callee_id)
);
create unique index one_live_call_per_space on public.partner_calls(couple_id) where status in ('ringing','accepted');
create index partner_calls_caller on public.partner_calls(caller_id,created_at desc);
create index partner_calls_callee on public.partner_calls(callee_id,created_at desc);
alter table public.partner_calls enable row level security;
revoke all on public.partner_calls from anon,authenticated;
grant select on public.partner_calls to authenticated;
create policy partner_calls_read on public.partner_calls for select to authenticated using((caller_id=(select auth.uid()) or callee_id=(select auth.uid())) and private.is_couple_member(couple_id));
-- Only the authenticated Edge Function can change lifecycle state.
create function public.manage_partner_call(actor uuid, operation text, call_id uuid default null, call_kind text default 'audio') returns public.partner_calls language plpgsql security invoker set search_path='' as $$
declare c public.partner_calls; space uuid; partner uuid;
begin
 select couple_id into space from public.profiles where id=actor;
 if space is null then raise exception 'Join your shared space first' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(space::text,0));
 update public.partner_calls set status=case when status='ringing' then 'missed' else 'ended' end,ended_at=now()
 where couple_id=space and ((status='ringing' and created_at<now()-interval '45 seconds') or (status='accepted' and (least(caller_seen,callee_seen)<now()-interval '90 seconds' or accepted_at<now()-interval '2 hours')));
 if operation='start' then
  select id into partner from public.profiles where couple_id=space and id<>actor;
  if partner is null then raise exception 'Your person has not joined this space yet';end if;
  if exists(select 1 from public.partner_calls where couple_id=space and status in ('ringing','accepted')) then raise exception 'A call is already in progress';end if;
  if (select count(*) from public.partner_calls where caller_id=actor and created_at>now()-interval '1 minute')>=3 then raise exception 'Please wait a moment before calling again';end if;
  insert into public.partner_calls(couple_id,caller_id,callee_id,kind) values(space,actor,partner,call_kind) returning * into c;
 else
  select * into c from public.partner_calls where id=call_id and couple_id=space and actor in(caller_id,callee_id) for update;
  if c.id is null then raise exception 'Call unavailable' using errcode='42501';end if;
  if operation='accept' and actor=c.callee_id and c.status='ringing' then
   update public.partner_calls set status='accepted',accepted_at=now(),callee_seen=now(),caller_seen=now() where id=c.id returning * into c;
  elsif operation='decline' and actor=c.callee_id and c.status='ringing' then
   update public.partner_calls set status='declined',ended_at=now() where id=c.id returning * into c;
  elsif operation='end' and c.status in ('ringing','accepted') then
   update public.partner_calls set status='ended',ended_at=now() where id=c.id returning * into c;
  elsif operation='heartbeat' and c.status='accepted' then
   update public.partner_calls set caller_seen=case when actor=caller_id then now() else caller_seen end,callee_seen=case when actor=callee_id then now() else callee_seen end where id=c.id returning * into c;
  elsif operation not in('status','token','accept','decline','end','heartbeat') then raise exception 'Invalid call action';end if;
 end if;
 return c;
end $$;
revoke all on function public.manage_partner_call(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.manage_partner_call(uuid,text,uuid,text) to service_role;
create function public.expire_partner_calls() returns void language sql security invoker set search_path='' as $$
 update public.partner_calls c set status=case when status='ringing' then 'missed' else 'ended' end,ended_at=now() where status in ('ringing','accepted') and (
 (status='ringing' and created_at<now()-interval '45 seconds') or
 (status='accepted' and (least(caller_seen,callee_seen)<now()-interval '90 seconds' or accepted_at<now()-interval '2 hours')) or
 (select count(*) from public.profiles p where p.couple_id=c.couple_id and p.id in(c.caller_id,c.callee_id))<>2);
$$;
revoke all on function public.expire_partner_calls() from public,anon,authenticated;
grant execute on function public.expire_partner_calls() to service_role;
create function private.close_departed_calls() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.couple_id is distinct from new.couple_id then update public.partner_calls set status='ended',ended_at=now() where couple_id=old.couple_id and status in('ringing','accepted');end if;return new;
end $$;
revoke all on function private.close_departed_calls() from public,anon,authenticated;
create trigger close_departed_calls after update of couple_id on public.profiles for each row execute function private.close_departed_calls();
alter publication supabase_realtime add table public.partner_calls;
create function private.dispatch_call_cleanup() returns void language sql security definer set search_path='' as $$
 select net.http_post(url:='https://dtjasplpglevmtagkrfp.supabase.co/functions/v1/cleanup-calls',headers:=jsonb_build_object('content-type','application/json','x-jigu-notification-secret',(select decrypted_secret from vault.decrypted_secrets where name='jigu_notification_secret')),body:='{}'::jsonb);
$$;
revoke all on function private.dispatch_call_cleanup() from public,anon,authenticated;
select cron.schedule('jigu-call-cleanup','* * * * *','select private.dispatch_call_cleanup()');
commit;
