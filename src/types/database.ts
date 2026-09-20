/**
 * Hand-written TypeScript types mirroring the Supabase schema in
 * /supabase/migrations. These exist so the rest of the app has real types
 * to import before a live Supabase project exists to generate them from.
 *
 * Once the Supabase project is created and the migrations have been run,
 * regenerate this file for real with the Supabase CLI instead of maintaining
 * it by hand:
 *
 *   npx supabase gen types typescript --project-id <your-project-id> > src/types/database.ts
 *
 * Until then, if you add or change a column, update both the migration SQL
 * and this file together.
 */

export type ProfileRole = "admin" | "member";
export type SeasonStatus = "upcoming" | "active" | "completed";
export type ContestantStatus =
  | "active"
  | "eliminated"
  | "winner"
  | "runner_up"
  | "withdrawn";
export type LeagueMemberRole = "owner" | "member";

export interface Profile {
  id: string;
  email: string;
  display_name: string | null;
  avatar_url: string | null;
  role: ProfileRole;
  created_at: string;
  updated_at: string;
}

export interface Show {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface Season {
  id: string;
  show_id: string;
  name: string;
  slug: string;
  season_number: number | null;
  status: SeasonStatus;
  start_date: string | null;
  end_date: string | null;
  created_at: string;
  updated_at: string;
}

export interface Contestant {
  id: string;
  season_id: string;
  name: string;
  bio: string | null;
  photo_url: string | null;
  status: ContestantStatus;
  status_detail: string | null;
  /** Show-specific, freeform data (e.g. { tribe: "Vati" }). */
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface League {
  id: string;
  season_id: string;
  name: string;
  invite_code: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface LeagueMember {
  id: string;
  league_id: string;
  profile_id: string;
  role: LeagueMemberRole;
  joined_at: string;
}

export interface Roster {
  id: string;
  league_member_id: string;
  name: string | null;
  created_at: string;
  updated_at: string;
}

export interface RosterEntry {
  id: string;
  roster_id: string;
  contestant_id: string;
  league_id: string;
  added_at: string;
  removed_at: string | null;
  created_at: string;
}

export interface Episode {
  id: string;
  season_id: string;
  episode_number: number;
  title: string | null;
  air_date: string | null;
  created_at: string;
  updated_at: string;
}

export interface ScoringEventType {
  id: string;
  show_id: string;
  key: string;
  label: string;
  description: string | null;
  default_points: number;
  created_at: string;
  updated_at: string;
}

export interface LeagueScoringRule {
  id: string;
  league_id: string;
  scoring_event_type_id: string;
  points: number;
  created_at: string;
  updated_at: string;
}

export interface ScoringEvent {
  id: string;
  episode_id: string;
  contestant_id: string;
  scoring_event_type_id: string;
  notes: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

/** Rows from the `league_effective_scoring_rules` view. */
export interface LeagueEffectiveScoringRule {
  league_id: string;
  season_id: string;
  show_id: string;
  scoring_event_type_id: string;
  key: string;
  label: string;
  points: number;
}

/** Rows from the `contestant_points_by_league` view. */
export interface ContestantPointsByLeague {
  scoring_event_id: string;
  contestant_id: string;
  league_id: string;
  episode_id: string;
  episode_number: number;
  scoring_event_type_id: string;
  event_key: string;
  event_label: string;
  points: number;
  notes: string | null;
  created_at: string;
}

/** Rows from the `contestant_episode_points` view. */
export interface ContestantEpisodePoints {
  contestant_id: string;
  league_id: string;
  episode_id: string;
  episode_number: number;
  episode_points: number;
}

/** Rows from the `contestant_season_points` view. */
export interface ContestantSeasonPoints {
  contestant_id: string;
  league_id: string;
  season_points: number;
}

/** Rows from the `league_standings` view. */
export interface LeagueStanding {
  league_id: string;
  league_member_id: string;
  profile_id: string;
  total_points: number;
}

/**
 * Minimal `Database` shape in the same style Supabase's generated types use,
 * so `createClient<Database>()` gives useful autocomplete without a live
 * project. This is intentionally partial (tables only, no Functions/Enums)
 * — replace with the generated file once available.
 */
export interface Database {
  public: {
    Tables: {
      profiles: { Row: Profile };
      shows: { Row: Show };
      seasons: { Row: Season };
      contestants: { Row: Contestant };
      leagues: { Row: League };
      league_members: { Row: LeagueMember };
      rosters: { Row: Roster };
      roster_entries: { Row: RosterEntry };
      episodes: { Row: Episode };
      scoring_event_types: { Row: ScoringEventType };
      league_scoring_rules: { Row: LeagueScoringRule };
      scoring_events: { Row: ScoringEvent };
    };
    Views: {
      league_effective_scoring_rules: { Row: LeagueEffectiveScoringRule };
      contestant_points_by_league: { Row: ContestantPointsByLeague };
      contestant_episode_points: { Row: ContestantEpisodePoints };
      contestant_season_points: { Row: ContestantSeasonPoints };
      league_standings: { Row: LeagueStanding };
    };
  };
}
