create table public.mood_journal_entries (
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  mood text,
  journal text,
  updated_at timestamptz not null default now(),
  primary key (user_id, entry_date),
  constraint valid_mood check (mood is null or mood in
    ('loved', 'joyful', 'missing', 'peaceful', 'needingHug',
     'angry', 'misunderstood', 'sad')),
  constraint journal_length check (journal is null or length(journal) <= 4000),
  constraint has_content check (mood is not null or nullif(trim(journal), '') is not null)
);

alter table public.mood_journal_entries enable row level security;
revoke all on public.mood_journal_entries from anon;
grant select, insert, delete on public.mood_journal_entries to authenticated;
grant update (mood, journal, updated_at) on public.mood_journal_entries to authenticated;

create policy mood_journal_select on public.mood_journal_entries
  for select to authenticated using (user_id = (select auth.uid()));
create policy mood_journal_insert on public.mood_journal_entries
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy mood_journal_update on public.mood_journal_entries
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy mood_journal_delete on public.mood_journal_entries
  for delete to authenticated using (user_id = (select auth.uid()));
