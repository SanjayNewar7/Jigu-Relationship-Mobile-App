-- Only the active partner's name can be changed through this narrow RPC.
-- Existing profile UPDATE policies remain self-only.
create or replace function public.rename_partner(partner_name text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  space uuid;
  partner uuid;
  cleaned text := pg_catalog.btrim(pg_catalog.regexp_replace(partner_name, '\s+', ' ', 'g'));
begin
  if actor is null then raise exception 'Please sign in again.'; end if;
  if cleaned is null or pg_catalog.length(cleaned) not between 2 and 40
    or cleaned ~ '[[:cntrl:]]' then
    raise exception 'Use a name between 2 and 40 characters.';
  end if;
  select p.couple_id into space from public.profiles p where p.id = actor;
  if space is null then raise exception 'Connect with your partner first.'; end if;
  perform p.id from public.profiles p where p.couple_id = space order by p.id for update;
  select other.id into partner
    from public.profiles mine
    join public.couples c on c.id = mine.couple_id
    join public.profiles other on other.couple_id = c.id and other.id <> mine.id
    where mine.id = actor and mine.couple_id = space
      and mine.id in (c.person_a, c.person_b)
      and other.id in (c.person_a, c.person_b);
  if partner is null then raise exception 'Your partner is no longer in this shared space.'; end if;
  update public.profiles set display_name = cleaned where id = partner;
  return cleaned;
end;
$$;
revoke all on function public.rename_partner(text) from public, anon;
grant execute on function public.rename_partner(text) to authenticated;
