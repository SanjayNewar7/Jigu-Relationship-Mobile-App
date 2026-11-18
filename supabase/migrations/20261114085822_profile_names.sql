alter table public.profiles
  add column display_name text
  constraint profile_display_name_valid check (
    display_name is null or (
      length(display_name) between 2 and 40
      and display_name = pg_catalog.btrim(display_name)
      and display_name !~ '[[:cntrl:]]'
    )
  );

grant update(display_name) on public.profiles to authenticated;
