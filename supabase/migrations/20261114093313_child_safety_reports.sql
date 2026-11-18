create table public.child_safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  category text not null check (category in ('child_safety', 'sexual_exploitation', 'other')),
  details text not null check (length(btrim(details)) between 20 and 4000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved')),
  created_at timestamptz not null default now()
);

create index child_safety_reports_created_at_idx
  on public.child_safety_reports (created_at desc);

alter table public.child_safety_reports enable row level security;
create policy child_safety_reports_submit on public.child_safety_reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()));

revoke all on public.child_safety_reports from anon, authenticated;
grant insert (reporter_id, category, details)
  on public.child_safety_reports to authenticated;
