-- RealityRostr — Data API grants
-- Run after 0004_row_level_security.sql.
--
-- This project was created with Supabase's "Automatically expose new
-- tables" option turned OFF (a deliberate choice — see CLAUDE.md). That
-- means Row Level Security alone is not enough for a table or view to be
-- reachable through the Data API (PostgREST/supabase-js): the `authenticated`
-- role also needs an explicit table-level GRANT, or every query fails with
-- "permission denied for table ...", regardless of RLS policy.
--
-- This is intentional defense-in-depth: a table isn't reachable at all
-- until BOTH a grant and an RLS policy allow it, rather than relying on RLS
-- as the only gate. There is no `anon` grant anywhere in this file — the
-- app has no unauthenticated access path, on purpose.

grant usage on schema public to authenticated;

-- Every table gets the full set of DML privileges. This does not weaken
-- anything: whether a given authenticated user can actually SELECT/INSERT/
-- UPDATE/DELETE a given row is still decided by the RLS policies in
-- 0004_row_level_security.sql (read: everyone; write: admins only). A grant
-- without a permissive RLS policy denies access just as effectively as no
-- grant at all — this step only removes the *table-level* block so RLS is
-- the single place access is actually decided.
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.shows to authenticated;
grant select, insert, update, delete on public.seasons to authenticated;
grant select, insert, update, delete on public.contestants to authenticated;
grant select, insert, update, delete on public.leagues to authenticated;
grant select, insert, update, delete on public.league_members to authenticated;
grant select, insert, update, delete on public.rosters to authenticated;
grant select, insert, update, delete on public.roster_entries to authenticated;
grant select, insert, update, delete on public.episodes to authenticated;
grant select, insert, update, delete on public.scoring_event_types to authenticated;
grant select, insert, update, delete on public.league_scoring_rules to authenticated;
grant select, insert, update, delete on public.scoring_events to authenticated;

-- Views are read-only from the app's perspective.
grant select on public.league_effective_scoring_rules to authenticated;
grant select on public.contestant_points_by_league to authenticated;
grant select on public.contestant_episode_points to authenticated;
grant select on public.contestant_season_points to authenticated;
grant select on public.roster_points to authenticated;
grant select on public.league_standings to authenticated;

-- Make this automatic for relations created by future migrations too, so a
-- new table (or view) added later doesn't silently 403 until someone
-- remembers this file exists. Postgres's default-privileges "TABLES" object
-- class covers views as well, so one statement handles both — granting
-- insert/update/delete on a future view that turns out to be read-only is
-- harmless; Postgres simply won't allow those operations to execute on it.
-- This only affects the grant layer — "Enable automatic RLS" (turned on for
-- this project) independently makes sure a brand-new table still starts
-- fully locked down by RLS until it has explicit policies, so the two
-- settings stack correctly rather than reopening the hole this migration
-- exists to close.
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
