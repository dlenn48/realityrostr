# CLAUDE.md

Persistent technical context for Claude sessions working on RealityRostr.
Read this before making architectural changes. Keep it updated whenever a
meaningful decision is made — this file, not conversation history, is what
lets a future session pick up where the last one left off.

## What RealityRostr is

A fantasy sports platform for reality competition TV — draft contestants
from shows like *Survivor* and *The Traitors*, score them episode by
episode against a flexible, per-show rule set, and compete in a private
league over a season. Currently being built as a private, family-only MVP
to replace a manually maintained scoreboard, with the explicit goal of
becoming a public multi-show platform later without a rewrite.

Owner/product owner: Dan (dlenn48@gmail.com). Dan acts as the sole
administrator during the MVP phase.

## Current development status

**Phase 1: Foundation — complete and machine-verified** (lint, typecheck,
and production build all pass; see "Environment note (resolved)" below).

Built:
- Next.js (App Router) + TypeScript + Tailwind CSS v4 project scaffold
- Full database schema + Row Level Security design (see below), as SQL
  migrations in `supabase/migrations/`
- Supabase client helpers (browser + server), not yet called from any page
- Hand-written TypeScript types mirroring the schema (`src/types/database.ts`)
- `.env.example`, `.gitignore`, README, this file, COSTS.md
- A minimal homepage that confirms the app builds and runs — no real UI yet

Not built yet (intentionally — see Recommended next steps):
- Authentication / login flows
- Any admin interface
- Any league/dashboard/roster-facing UI
- Live Supabase project (Dan needs to create one — see README's Local setup)

### Environment note (resolved)

Phase 1 was originally built in a sandbox that blocked the npm registry,
plus a temporarily broken bridge to Dan's computer, so nothing was
machine-verified at first. Both were resolved within the same session:

- `npm install`, `npm run lint`, `npm run typecheck` all run and pass
  cleanly (verified via a shell on Dan's computer).
- `npm run build` passes (verified in Dan's own Windows terminal — the
  Linux bridge shell lacks the native SWC binary Turbopack needs and
  couldn't download one, since it can't reach the npm registry either;
  that's a limitation of that one shell, not of the project).
- Along the way, a real bug was found and fixed: the FlatCompat-based
  `eslint.config.mjs` pattern (the documented pattern as of Next 15)
  crashes under Next.js 16 / eslint-config-next 16 with "TypeError:
  Converting circular structure to JSON" — eslint-config-next@16 now
  ships native flat config arrays, so wrapping them in FlatCompat
  double-wraps the plugin objects into a circular reference. Fixed by
  importing and spreading `eslint-config-next/core-web-vitals` and
  `eslint-config-next/typescript` directly. If you ever see this error
  again after a dependency bump, this is the first thing to check.

## Technology stack

Next.js (App Router, TypeScript) + Tailwind CSS v4 + Supabase (Postgres +
Auth) + Vercel + GitHub. See README.md for the "why" on each, and COSTS.md
for the free-tier accounting. This stack was evaluated up front against the
$0-operating-cost requirement and confirmed sufficient — see COSTS.md for
the specific limits checked.

## Project architecture

```
src/
  app/                    Next.js App Router routes
  lib/
    supabase/
      client.ts            Browser Supabase client
      server.ts             Server Supabase client (Server Components, Route Handlers, Server Actions)
  types/
    database.ts             Hand-written types mirroring the schema (regenerate via Supabase CLI once a live project exists)
supabase/
  migrations/               Numbered plain-SQL migrations, run manually via the Supabase SQL Editor
```

As real features are added, prefer organizing `src/app` by route group
(e.g. `(dashboard)`, `(admin)`) and giving each non-trivial feature its own
module under `src/lib` (e.g. `src/lib/leagues/`, `src/lib/scoring/`) rather
than one large shared file. Nothing in Phase 1 needed this yet.

## Database architecture

Twelve tables plus five views, described fully in the migration files
themselves (each has extensive comments — read those before this summary if
you need the exact columns/constraints):

**Tables:** `profiles`, `shows`, `seasons`, `contestants`, `leagues`,
`league_members`, `rosters`, `roster_entries`, `episodes`,
`scoring_event_types`, `league_scoring_rules`, `scoring_events`.

**Views (all computed live, nothing cached):**
`league_effective_scoring_rules`, `contestant_points_by_league`,
`contestant_episode_points`, `contestant_season_points`, `roster_points`,
`league_standings`.

### Database design principles (do not casually violate these)

1. **No show-specific columns, ever.** `contestants` has no
   `immunity_wins`, `shields_won`, etc. Anything show-specific is either a
   row in `scoring_event_types` (for things that affect scoring) or a key in
   `contestants.metadata` jsonb (for flavor data like a tribe name). This is
   what lets a brand-new show be configured entirely through the admin UI
   with zero migrations.
2. **Scoring is an append-only ledger with no stored totals.**
   `scoring_events` records what happened; it does **not** store a point
   value. Every total (episode, season, roster, league standings) is a live
   SQL view. Correcting a mistake means editing or deleting a
   `scoring_events` row — every downstream total updates automatically, and
   there is exactly one source of truth for "what happened" and exactly one
   place ("the views") that turns it into points.
3. **A season can have more than one league.** Scoring rules resolve
   per-league (`league_effective_scoring_rules`: a league's own override, or
   the show's `default_points` if it has none), not per-season, because two
   families could draft the same season with different house rules. Don't
   assume "one league per season" when writing new queries.
4. **A contestant can only be actively rostered once per league.** Enforced
   at the database level via a partial unique index on
   `roster_entries (league_id, contestant_id) where removed_at is null` —
   not just app-layer validation. `roster_entries.league_id` is a
   denormalized column, kept in sync by a trigger
   (`sync_roster_entry_league_id`) specifically to make that constraint
   possible; never write to it directly from application code.
5. **`profiles.role` is site-wide, not per-league.** There is intentionally
   no separate roles/permissions table yet — with one admin (Dan) and a
   handful of family members, that would be complexity with no present
   benefit. `league_members.role` (`owner`/`member`) already exists for any
   future per-league permission need. If a genuine need for finer-grained
   roles ever appears, extend from there rather than reintroducing a global
   roles table.

## Authentication / authorization approach

- **Authentication:** Supabase Auth. No login UI exists yet (Phase 2). The
  intended method is Supabase's magic-link / OTP email sign-in — no
  passwords to manage for a handful of family members, and it stays within
  Supabase's free-tier built-in email sending. This can be revisited if it
  proves inconvenient.
- **Authorization is enforced in the database, not the client.** Every
  table has Row Level Security enabled (`0004_row_level_security.sql`).
  Phase 1's policy shape: any authenticated user can **read** everything;
  only a user with `profiles.role = 'admin'` can **write** anything. This is
  intentionally coarse (no per-league read restriction yet) because family
  members currently share one "space" — tightening it to
  per-league-membership visibility later is additive (the
  `is_league_member()` helper function already exists for that, just isn't
  used by any policy yet) and should not require restructuring existing
  policies, only adding conditions to them.
  Never trust a hidden button or disabled UI element as the only guard on
  an admin action — the actual enforcement is the RLS policy plus, for the
  `profiles.role` field specifically, the `prevent_profile_role_escalation`
  trigger (a user cannot promote their own role even via a direct API call).
- **First admin:** no user starts as admin. After Dan signs up through the
  app (once Phase 2 builds sign-in), he needs to run one SQL statement in
  the Supabase SQL Editor to promote himself — documented in README.md's
  Database setup section. This is a one-time manual step, not a bug.

## Scoring architecture

See "Database design principles" above (#2 and #3) for the core model.
Summary of the flow for a new scoring entry:

1. Admin picks an episode, a contestant, and a `scoring_event_type` (e.g.
   "Won Immunity") and records a `scoring_events` row. No point value is
   entered here — the event just says what happened.
2. `league_effective_scoring_rules` resolves what that event type is worth
   *for a specific league* (the league's override, or the show's default).
3. `contestant_points_by_league` joins those together into "this event was
   worth N points in this league."
4. `contestant_episode_points` / `contestant_season_points` /
   `roster_points` / `league_standings` aggregate upward from there.

A UI showing "Episode 4: Survived Episode +2, Won Shield +5 — Episode Total:
+7, Season Total: 28" (the example from the product brief) is just a
formatted read of `contestant_points_by_league` filtered to one episode,
plus `contestant_season_points` for the running total. No separate
calculation code should be needed — if you find yourself computing points in
application code instead of reading a view, stop and reconsider.

## Development conventions

- Schema changes are new numbered migration files
  (`000N_description.sql`), never edits to an already-applied migration.
- Every new external service/dependency gets an entry in COSTS.md *before*
  being adopted — purpose, cost, free-tier limits, what would trigger a
  cost, and a migration path. Don't add a paid or usage-billed dependency
  without surfacing that to Dan first.
- Prefer deriving data via SQL views over caching/duplicating it in
  application code or additional columns — this is the same principle as
  scoring principle #2, applied generally.
- Keep this file and README.md current when you make a decision a future
  session would otherwise have to rediscover.

## Important commands

```bash
npm run dev        # local dev server
npm run build      # production build
npm run lint        # ESLint
npm run typecheck   # tsc --noEmit
```

## Environment setup

See README.md's "Local setup" and "Required environment variables" sections
— not duplicated here to avoid the two files drifting out of sync.

## External services

See COSTS.md for the full accounting (purpose, tier, limits, migration
path) of Supabase, Vercel, and GitHub. All three are free at current scale.

## Cost constraints

$0/month operating cost beyond the already-purchased realityrostr.com
domain is a hard requirement at this stage, not a preference. See COSTS.md.
Any change that would introduce a paid or usage-billed dependency needs to
be flagged to Dan explicitly before being implemented, per the project
brief.

## Decisions that should not be casually reversed

- **No stored point totals anywhere.** Adding a `total_points` column
  "for performance" would reintroduce exactly the duplicated-source-of-truth
  problem the schema was designed to avoid. If performance ever genuinely
  requires it, use a materialized view with an explicit refresh strategy,
  not a manually-maintained column.
- **No show-specific columns on `contestants` or anywhere else in the core
  schema.** Use `scoring_event_types` and `contestants.metadata` instead.
- **RLS stays enabled on every table**, even during development. Don't
  disable it "temporarily" to make debugging easier.
- **`roster_entries.league_id` is trigger-maintained, not app-maintained.**
  Don't start setting it from application code — that reopens the
  possibility of it disagreeing with the roster's actual league.

## Known issues / technical debt

- **`profiles_admin_all` RLS policy permits an admin to `DELETE` a
  `profiles` row directly.** Doing so would orphan the corresponding
  `auth.users` row (there's no reverse cascade). Removing a family member
  should go through Supabase's Auth user management, not a direct
  `profiles` delete. Not fixed now because it's a minor MVP-scale edge case,
  but worth a guard (e.g. a `BEFORE DELETE` trigger, or simply removing
  `DELETE` from that policy) if an admin UI ever exposes profile deletion
  directly.
- **`roster_points` sums a contestant's entire season total**, even points
  scored before they joined a given roster. Correct for Phase 1 (rosters
  are set once at draft time and don't change), but would need to become
  a time-windowed sum (`added_at` to `removed_at`) if in-season trading is
  ever added.
- **Supabase free-tier project auto-pause after 7 days of inactivity** is a
  real operational quirk for a seasonal app — see COSTS.md. Not a code
  issue, just something Dan needs to remember between seasons.
- **No live Supabase project exists yet.** The migrations are written and
  reviewed but have never been run against a real database. Running them
  and confirming they apply cleanly is part of Phase 2 setup, not something
  Claude could verify without Dan's Supabase credentials.

## Completed functionality

- Project scaffold, environment/config handling, and documentation (this
  Phase 1 task).
- Full schema design (not yet applied to a live database — see Known
  issues).

Nothing user-facing exists yet — no sign-in, no dashboard, no admin tools.

## Recommended next steps (Phase 2 candidate)

In rough priority order:

1. **Stand up the real Supabase project** and run the four migrations
   against it; confirm the schema applies cleanly and RLS behaves as
   designed (e.g. try reading/writing as a non-admin user and confirm writes
   are rejected).
2. **Authentication.** Build the actual magic-link sign-in flow and the
   session-refresh middleware/proxy the Supabase SSR docs describe (not
   built in Phase 1 — the client/server helpers are ready for it but nothing
   calls them yet).
3. **Seed Dan's real data.** Use the admin SQL/dashboard to create the
   *Survivor* and *Traitors* shows, current seasons, contestants, and a
   first league, so there's real data to build UI against.
4. **Minimal admin CRUD** for shows/seasons/contestants/episodes/scoring
   events — even a plain form-based interface — before investing in the
   polished family-facing UI, since Dan needs this to enter real data.
5. **Family-facing read views**: league standings, a roster page, an
   episode scoring breakdown — reading from the views already built.

Do not start any of these without Dan's explicit go-ahead — Phase 1 is
scoped to stop here and wait for review, per the project brief.
