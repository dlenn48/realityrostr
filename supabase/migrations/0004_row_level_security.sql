-- RealityRostr — Row Level Security
-- Run after 0003_views.sql.
--
-- Phase 1 policy shape (deliberately simple, tightened later if RealityRostr
-- ever goes public):
--   - Any signed-in user (i.e. any family member) can READ everything.
--   - Only an admin (profiles.role = 'admin') can WRITE anything.
-- This is enough to satisfy "regular users are read-only" and "scores can't
-- be manipulated from the browser" today. Per-league visibility (using
-- is_league_member(), already defined in 0002) is a straightforward
-- follow-up once RealityRostr has leagues that shouldn't see each other.

alter table public.profiles enable row level security;
alter table public.shows enable row level security;
alter table public.seasons enable row level security;
alter table public.contestants enable row level security;
alter table public.leagues enable row level security;
alter table public.league_members enable row level security;
alter table public.rosters enable row level security;
alter table public.roster_entries enable row level security;
alter table public.episodes enable row level security;
alter table public.scoring_event_types enable row level security;
alter table public.league_scoring_rules enable row level security;
alter table public.scoring_events enable row level security;

-- profiles: everyone signed in can see everyone (it's a family app); a user
-- may update their own row (role changes are blocked by the trigger in
-- 0002, not by this policy); only admins can update anyone else's or insert
-- rows out of band (normal signup goes through the handle_new_user trigger,
-- which runs as security definer and bypasses this).
create policy "profiles_select_authenticated" on public.profiles
  for select to authenticated using (true);

create policy "profiles_update_own_or_admin" on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy "profiles_admin_all" on public.profiles
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Reference/show data: read for everyone signed in, write for admins only.
create policy "shows_select_authenticated" on public.shows
  for select to authenticated using (true);
create policy "shows_admin_write" on public.shows
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "seasons_select_authenticated" on public.seasons
  for select to authenticated using (true);
create policy "seasons_admin_write" on public.seasons
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "contestants_select_authenticated" on public.contestants
  for select to authenticated using (true);
create policy "contestants_admin_write" on public.contestants
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "episodes_select_authenticated" on public.episodes
  for select to authenticated using (true);
create policy "episodes_admin_write" on public.episodes
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "scoring_event_types_select_authenticated" on public.scoring_event_types
  for select to authenticated using (true);
create policy "scoring_event_types_admin_write" on public.scoring_event_types
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- League data: read for everyone signed in (a small family shares one
-- "space"); write for admins only, since drafting/roster assignment/league
-- creation is admin-managed in Phase 1.
create policy "leagues_select_authenticated" on public.leagues
  for select to authenticated using (true);
create policy "leagues_admin_write" on public.leagues
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "league_members_select_authenticated" on public.league_members
  for select to authenticated using (true);
create policy "league_members_admin_write" on public.league_members
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "rosters_select_authenticated" on public.rosters
  for select to authenticated using (true);
create policy "rosters_admin_write" on public.rosters
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "roster_entries_select_authenticated" on public.roster_entries
  for select to authenticated using (true);
create policy "roster_entries_admin_write" on public.roster_entries
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "league_scoring_rules_select_authenticated" on public.league_scoring_rules
  for select to authenticated using (true);
create policy "league_scoring_rules_admin_write" on public.league_scoring_rules
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- scoring_events is the one table where "no client-side score manipulation"
-- matters most: only an admin can insert/update/delete. Every family member
-- can read the full ledger (so they can see exactly why totals are what
-- they are).
create policy "scoring_events_select_authenticated" on public.scoring_events
  for select to authenticated using (true);
create policy "scoring_events_admin_write" on public.scoring_events
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
