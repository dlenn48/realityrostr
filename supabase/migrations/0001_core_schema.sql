-- RealityRostr — Core schema
-- Phase 1 foundation. Run this in the Supabase SQL Editor (or via `supabase db push`
-- once the CLI workflow is adopted) in order: 0001, 0002, 0003, 0004.
--
-- Design principles (see /CLAUDE.md for the full rationale):
--   1. Nothing here is Survivor- or Traitors-specific. Shows define their own
--      vocabulary of scoring events; contestants never get show-specific columns.
--   2. Scoring is an append-only ledger (scoring_events). Point values are never
--      stored redundantly — they are always derived from scoring_event_types /
--      league_scoring_rules at query time (see 0003_views.sql). Correcting a
--      mistake means editing or deleting the offending row; every total
--      recalculates automatically because nothing downstream caches a total.
--   3. A league belongs to exactly one season, but a season may have more than
--      one league (e.g. two family branches drafting the same season with
--      different house rules) — so scoring rules are resolved per-league, not
--      hardcoded to "the" league for a season.

create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ---------------------------------------------------------------------------
-- profiles: one row per authenticated user, 1:1 with auth.users.
-- role is a simple site-wide flag. It is intentionally NOT a separate
-- roles/permissions table for Phase 1 — with one admin (Dan) and a handful of
-- family members, a `roles` join table would be complexity with no present
-- benefit. If per-league admin roles are ever needed, league_members.role
-- (below) already covers that; profiles.role is only for site-wide
-- administration (managing shows/seasons/contestants/leagues/scoring).
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text,
  avatar_url text,
  role text not null default 'member' check (role in ('admin', 'member')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'One row per authenticated user. Auto-created by handle_new_user() on signup (see 0002).';
comment on column public.profiles.role is 'Site-wide role: admin can manage all shows/seasons/leagues/scoring. member is read-only. Not per-league — see league_members.role for that.';

-- ---------------------------------------------------------------------------
-- shows: the overall TV property (Survivor, The Traitors, ...).
-- ---------------------------------------------------------------------------
create table public.shows (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- seasons: a specific season of a show (Survivor 51, The Traitors Season 4).
-- ---------------------------------------------------------------------------
create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  show_id uuid not null references public.shows (id) on delete cascade,
  name text not null,
  slug text not null,
  season_number integer,
  status text not null default 'upcoming' check (status in ('upcoming', 'active', 'completed')),
  start_date date,
  end_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (show_id, slug)
);

create index idx_seasons_show_id on public.seasons (show_id);

-- ---------------------------------------------------------------------------
-- contestants: belong to a season. Status is a small, generic enum plus a
-- free-form `metadata` jsonb column for anything show-specific (tribe name,
-- starting edge, recruit/faction, etc.) so a brand-new show never requires a
-- schema change to represent its flavor of contestant data.
-- ---------------------------------------------------------------------------
create table public.contestants (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  name text not null,
  bio text,
  photo_url text,
  status text not null default 'active' check (status in ('active', 'eliminated', 'winner', 'runner_up', 'withdrawn')),
  status_detail text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (season_id, name)
);

comment on column public.contestants.metadata is 'Free-form, show-specific data (e.g. {"tribe": "Vati"} or {"faction": "Traitor"}). Deliberately schemaless so new shows never require a migration.';
comment on column public.contestants.status is 'Small generic set. Adding a new value later is a one-line constraint change, not a redesign — see CLAUDE.md.';

create index idx_contestants_season_id on public.contestants (season_id);

-- ---------------------------------------------------------------------------
-- leagues: a group of users competing over one show/season.
-- ---------------------------------------------------------------------------
create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete restrict,
  name text not null,
  invite_code text unique,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.leagues.invite_code is 'Reserved for future self-serve invites. Unused while Dan adds family members manually in Phase 1.';

create index idx_leagues_season_id on public.leagues (season_id);

-- ---------------------------------------------------------------------------
-- league_members: who's in a league, and their role within it.
-- ---------------------------------------------------------------------------
create table public.league_members (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  unique (league_id, profile_id)
);

create index idx_league_members_league_id on public.league_members (league_id);
create index idx_league_members_profile_id on public.league_members (profile_id);

-- ---------------------------------------------------------------------------
-- rosters: one fantasy team per league membership.
-- Modeled as its own table (rather than columns on league_members) so a
-- future "multiple rosters per member" feature (e.g. a mid-season redraft)
-- doesn't require restructuring — it would just relax the unique constraint
-- below.
-- ---------------------------------------------------------------------------
create table public.rosters (
  id uuid primary key default gen_random_uuid(),
  league_member_id uuid not null references public.league_members (id) on delete cascade,
  name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (league_member_id)
);

-- ---------------------------------------------------------------------------
-- roster_entries: which contestants are (or were) on a roster.
-- league_id is denormalized from roster -> league_member -> league purely to
-- support the cross-roster integrity constraint below (a contestant can only
-- be actively rostered once per league) without a trigger-based lookup on
-- every read. It is populated by a trigger, never written directly by the app.
-- ---------------------------------------------------------------------------
create table public.roster_entries (
  id uuid primary key default gen_random_uuid(),
  roster_id uuid not null references public.rosters (id) on delete cascade,
  contestant_id uuid not null references public.contestants (id) on delete restrict,
  league_id uuid not null references public.leagues (id) on delete cascade,
  added_at timestamptz not null default now(),
  removed_at timestamptz,
  created_at timestamptz not null default now()
);

comment on column public.roster_entries.league_id is 'Denormalized (set by a trigger from roster_id) so we can enforce "one active owner per contestant per league" with a plain unique index. Never set this directly from the app.';
comment on column public.roster_entries.removed_at is 'Null = currently on the roster. Set instead of deleting, so roster history is preserved.';

create index idx_roster_entries_roster_id on public.roster_entries (roster_id);
create index idx_roster_entries_contestant_id on public.roster_entries (contestant_id);

-- A contestant may be actively rostered by only one roster within a league.
create unique index ux_roster_entries_active_contestant_per_league
  on public.roster_entries (league_id, contestant_id)
  where removed_at is null;

-- A roster may not roster the same contestant twice at once.
create unique index ux_roster_entries_active_contestant_per_roster
  on public.roster_entries (roster_id, contestant_id)
  where removed_at is null;

-- ---------------------------------------------------------------------------
-- episodes: belong to a season. Scoring events attach to an episode so both
-- per-episode and season-to-date totals can be shown.
-- ---------------------------------------------------------------------------
create table public.episodes (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  episode_number integer not null,
  title text,
  air_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (season_id, episode_number)
);

create index idx_episodes_season_id on public.episodes (season_id);

-- ---------------------------------------------------------------------------
-- scoring_event_types: the vocabulary of things that can happen on a show
-- ("Survived Episode", "Won Immunity", "Got Murdered", ...). Belongs to a
-- show (not a season), since the ruleset for a show is normally stable
-- across its seasons. default_points is the fallback used when a league
-- hasn't defined its own point value for this event (see 0003_views.sql).
-- ---------------------------------------------------------------------------
create table public.scoring_event_types (
  id uuid primary key default gen_random_uuid(),
  show_id uuid not null references public.shows (id) on delete cascade,
  key text not null,
  label text not null,
  description text,
  default_points numeric(6, 2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (show_id, key)
);

create index idx_scoring_event_types_show_id on public.scoring_event_types (show_id);

-- ---------------------------------------------------------------------------
-- league_scoring_rules: optional per-league override of a scoring event's
-- point value. If a league has no row for a given event type, the show's
-- default_points applies (see the league_effective_scoring_rules view).
-- ---------------------------------------------------------------------------
create table public.league_scoring_rules (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete cascade,
  scoring_event_type_id uuid not null references public.scoring_event_types (id) on delete cascade,
  points numeric(6, 2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (league_id, scoring_event_type_id)
);

create index idx_league_scoring_rules_league_id on public.league_scoring_rules (league_id);

-- ---------------------------------------------------------------------------
-- scoring_events: the audit ledger. One row per occurrence of an event for a
-- contestant in an episode. Deliberately does NOT store a point value —
-- points are always derived (via a view) from scoring_event_types /
-- league_scoring_rules, so there is exactly one source of truth for "what is
-- this event worth." If the same event happens twice in an episode (e.g. two
-- advantages found), insert two rows rather than a quantity column, so the
-- episode breakdown reads naturally ("Found Advantage +3, Found Advantage +3").
-- ---------------------------------------------------------------------------
create table public.scoring_events (
  id uuid primary key default gen_random_uuid(),
  episode_id uuid not null references public.episodes (id) on delete cascade,
  contestant_id uuid not null references public.contestants (id) on delete cascade,
  scoring_event_type_id uuid not null references public.scoring_event_types (id) on delete restrict,
  notes text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.scoring_events is 'Append-mostly audit ledger of what happened. No stored point value by design — see league_effective_scoring_rules / contestant_points_by_league views. Correct a mistake by editing or deleting the row; every total recalculates.';

create index idx_scoring_events_episode_id on public.scoring_events (episode_id);
create index idx_scoring_events_contestant_id on public.scoring_events (contestant_id);
create index idx_scoring_events_scoring_event_type_id on public.scoring_events (scoring_event_type_id);
