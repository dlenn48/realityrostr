-- RealityRostr — Scoring views
-- Run after 0002_functions_and_triggers.sql.
--
-- These views are the single place points are computed. Nothing in the
-- schema stores a total; every total below is a live aggregation, so
-- correcting a scoring_events row (or a league's point value for an event
-- type) is immediately reflected everywhere without a recalculation step.

-- ---------------------------------------------------------------------------
-- league_effective_scoring_rules: for every (league, scoring event type)
-- pair possible for that league's show, the point value that actually
-- applies — the league's own override if it has one, otherwise the show's
-- default.
-- ---------------------------------------------------------------------------
create or replace view public.league_effective_scoring_rules as
select
  l.id as league_id,
  s.id as season_id,
  sh.id as show_id,
  et.id as scoring_event_type_id,
  et.key,
  et.label,
  coalesce(lsr.points, et.default_points) as points
from public.leagues l
join public.seasons s on s.id = l.season_id
join public.shows sh on sh.id = s.show_id
join public.scoring_event_types et on et.show_id = sh.id
left join public.league_scoring_rules lsr
  on lsr.league_id = l.id and lsr.scoring_event_type_id = et.id;

comment on view public.league_effective_scoring_rules is 'Resolves the point value a league actually uses for each scoring event type: the league''s override if set, else the show''s default.';

-- ---------------------------------------------------------------------------
-- contestant_points_by_league: every recorded scoring event, expanded to the
-- point value it's worth in each league that covers that contestant's
-- season. One event can appear multiple times if more than one league is
-- running the same season (each with its own point value).
-- ---------------------------------------------------------------------------
create or replace view public.contestant_points_by_league as
select
  se.id as scoring_event_id,
  se.contestant_id,
  ler.league_id,
  se.episode_id,
  ep.episode_number,
  se.scoring_event_type_id,
  ler.key as event_key,
  ler.label as event_label,
  ler.points,
  se.notes,
  se.created_at
from public.scoring_events se
join public.episodes ep on ep.id = se.episode_id
join public.contestants c on c.id = se.contestant_id and c.season_id = ep.season_id
join public.league_effective_scoring_rules ler
  on ler.season_id = ep.season_id
  and ler.scoring_event_type_id = se.scoring_event_type_id;

-- ---------------------------------------------------------------------------
-- contestant_episode_points: per-contestant, per-league, per-episode totals.
-- ---------------------------------------------------------------------------
create or replace view public.contestant_episode_points as
select
  contestant_id,
  league_id,
  episode_id,
  episode_number,
  sum(points) as episode_points
from public.contestant_points_by_league
group by contestant_id, league_id, episode_id, episode_number;

-- ---------------------------------------------------------------------------
-- contestant_season_points: per-contestant, per-league season-to-date totals.
-- ---------------------------------------------------------------------------
create or replace view public.contestant_season_points as
select
  contestant_id,
  league_id,
  sum(points) as season_points
from public.contestant_points_by_league
group by contestant_id, league_id;

-- ---------------------------------------------------------------------------
-- roster_points: for every currently-active roster_entry, the contestant's
-- season points in that league, attributed to the owning roster/member.
-- MVP simplification: this sums the contestant's FULL season total, even for
-- points scored before the contestant joined this particular roster. That's
-- fine while rosters are set once at draft time (Phase 1); if in-season
-- trading is added later, this view should instead sum only the points
-- scored between roster_entries.added_at and removed_at.
-- ---------------------------------------------------------------------------
create or replace view public.roster_points as
select
  re.roster_id,
  r.league_member_id,
  lm.league_id,
  lm.profile_id,
  re.contestant_id,
  coalesce(csp.season_points, 0) as contestant_season_points
from public.roster_entries re
join public.rosters r on r.id = re.roster_id
join public.league_members lm on lm.id = r.league_member_id
left join public.contestant_season_points csp
  on csp.contestant_id = re.contestant_id and csp.league_id = lm.league_id
where re.removed_at is null;

-- ---------------------------------------------------------------------------
-- league_standings: total points per league member, across their whole
-- roster, ordered highest first.
-- ---------------------------------------------------------------------------
create or replace view public.league_standings as
select
  league_id,
  league_member_id,
  profile_id,
  sum(contestant_season_points) as total_points
from public.roster_points
group by league_id, league_member_id, profile_id
order by league_id, total_points desc;
