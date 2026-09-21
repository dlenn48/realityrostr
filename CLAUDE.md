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

**Phase 2 (partial): Supabase + Auth — complete and machine-verified.**
Dan explicitly scoped this pass to "Supabase setup + authentication only" —
data seeding, admin CRUD, and family-facing UI are deliberately deferred to
a later pass (see Recommended next steps).

Built in Phase 1 (foundation):
- Next.js (App Router) + TypeScript + Tailwind CSS v4 project scaffold
- Full database schema + Row Level Security design, as SQL migrations in
  `supabase/migrations/`
- Supabase client helpers (browser + server)
- Hand-written TypeScript types mirroring the schema (`src/types/database.ts`)
- `.env.example`, `.gitignore`, README, this file, COSTS.md

Built in Phase 2 (this pass):
- A real Supabase project exists (org: a new "Personal" org, separate from
  Dan's Orivian org, on the same Supabase account — see "Supabase project
  setup" below for why). All five migrations (0001–0005) are applied to it.
- Working magic-link sign-in, end-to-end, verified by Dan against the real
  project: `/login` (request a link) → email → `/auth/callback` (exchanges
  the code for a session) → signed-in state shown on `/`.
- `src/proxy.ts` — session-refresh Proxy (Next.js 16's renamed
  `middleware.ts` convention; see the file's own comment for the doc link).
- `src/app/actions/auth.ts` — a `signOut()` Server Action.
- `.env.local` exists on Dan's machine with real (non-secret) project
  credentials — never committed, see `.gitignore`.

Not built yet (intentionally — see Recommended next steps):
- Any real show/season/contestant data — the database is schema-only, no
  rows yet beyond whatever `auth.users`/`profiles` rows sign-in creates.
- Any admin interface.
- Any league/dashboard/roster-facing UI.
- Dan has not yet promoted himself to `admin` — see "First admin" below.

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

## Supabase project setup

- **Account/org:** Dan's existing Supabase account (shared with his
  separate Orivian project), but a **new organization** was created for
  RealityRostr rather than reusing Orivian's org. Reasoning: Supabase's
  free-tier project quota is per-organization, not per-account, so a new
  org gets its own quota and its own access boundary (if Orivian's org
  ever gets an outside collaborator, they have zero visibility into this
  project) without the overhead of a whole separate Supabase account/login.
- **Project creation security settings** (this matters — see below):
  - **Enable Data API:** on (required — the app talks to Postgres only
    through the auto-generated Data API via `@supabase/supabase-js`).
  - **Automatically expose new tables:** turned **off**, against the
    project-creation wizard's own default. Supabase's default (on) means a
    new table becomes reachable through the Data API the moment it's
    created, relying on RLS as the only gate. Off means a table additionally
    needs an explicit `GRANT` before it's reachable at all — defense in
    depth on top of RLS, not instead of it. This is why
    `0005_data_api_grants.sql` exists: it grants `select/insert/update/delete`
    on every table (and `select` on every view) to the `authenticated` role
    only — deliberately never to `anon`, since the app has no unauthenticated
    data access path. It also sets a default-privileges rule so tables added
    by *future* migrations inherit the same grant automatically — don't
    forget it still needs RLS policies too (see the next bullet).
  - **Enable automatic RLS:** turned **on**, against the wizard's own
    default (off). This makes Supabase auto-enable (default-deny) RLS on
    any table created outside of a reviewed migration — e.g. if Dan ever
    creates one by hand in the Table Editor — so an accidental table starts
    locked down instead of wide open. It's a safety net; every table this
    project actually ships still gets RLS enabled explicitly in
    `0004_row_level_security.sql` regardless.
  - Net effect: a table in this project is reachable through the API only
    if it has *both* a `GRANT` (0005) *and* a permissive RLS policy (0004).
    Missing either one and a query fails closed, not open.
- **Running migrations:** there is no Supabase CLI / `supabase db push`
  workflow set up (deliberately, for MVP simplicity — see the "Simplicity"
  cost/architecture principle). All five `supabase/migrations/*.sql` files
  were pasted into the Supabase Dashboard's SQL Editor and run in order,
  by Dan, one at a time. If a Phase 3+ session adopts the CLI workflow
  instead, update this section and README's Database setup accordingly.
- **Auth email:** using Supabase's built-in low-volume email sending for
  magic links (free tier — see COSTS.md). No custom SMTP configured.
- **First admin:** still outstanding. `profiles.role` defaults to
  `'member'` for everyone, Dan included. Before any admin feature is built,
  run this once in the SQL Editor (see README's Database setup for the
  exact statement) to promote Dan's own profile to `'admin'`.

## Technology stack

Next.js (App Router, TypeScript) + Tailwind CSS v4 + Supabase (Postgres +
Auth) + Vercel + GitHub. See README.md for the "why" on each, and COSTS.md
for the free-tier accounting. This stack was evaluated up front against the
$0-operating-cost requirement and confirmed sufficient — see COSTS.md for
the specific limits checked.

## Project architecture

```
src/
  app/
    login/page.tsx          Magic-link sign-in form (Client Component)
    auth/callback/route.ts   Exchanges the emailed code for a session, redirects in
    actions/auth.ts          signOut() Server Action
    page.tsx                  Homepage — shows signed-in state
  lib/
    supabase/
      client.ts            Browser Supabase client
      server.ts             Server Supabase client (Server Components, Route Handlers, Server Actions)
  types/
    database.ts             Hand-written types mirroring the schema (regenerate via Supabase CLI once adopted)
  proxy.ts                   Session-refresh Proxy (Next.js 16's renamed middleware.ts)
supabase/
  migrations/               Numbered plain-SQL migrations (0001-0005), run manually via the Supabase SQL Editor
```

As real features are added, prefer organizing `src/app` by route group
(e.g. `(dashboard)`, `(admin)`) and giving each non-trivial feature its own
module under `src/lib` (e.g. `src/lib/leagues/`, `src/lib/scoring/`) rather
than one large shared file. Nothing built so far needed this yet.

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

See "Supabase project setup" above for the Data API grants
(`0005_data_api_grants.sql`) that sit alongside RLS as a second access-control
layer — both are required for a table to be reachable at all.

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

- **Authentication:** Supabase Auth via magic-link / OTP email sign-in — no
  passwords to manage for a handful of family members, and it stays within
  Supabase's free-tier built-in email sending. **Built and verified working
  end-to-end** (see "Current development status"). Flow: `src/app/login`
  calls `supabase.auth.signInWithOtp()` → Supabase emails a link to
  `/auth/callback?code=...` → `src/app/auth/callback/route.ts` exchanges the
  code for a session via `exchangeCodeForSession()` → `src/proxy.ts` keeps
  that session refreshed on every subsequent request.
- **Authorization is enforced in the database, not the client.** Every
  table has Row Level Security enabled (`0004_row_level_security.sql`) *and*
  an explicit Data API grant (`0005_data_api_grants.sql` — see "Supabase
  project setup" for why both layers exist). Current policy shape: any
  authenticated user can **read** everything; only a user with
  `profiles.role = 'admin'` can **write** anything. This is intentionally
  coarse (no per-league read restriction yet) because family members
  currently share one "space" — tightening it to per-league-membership
  visibility later is additive (the `is_league_member()` helper function
  already exists for that, just isn't used by any policy yet) and should
  not require restructuring existing policies, only adding conditions to
  them.
  Never trust a hidden button or disabled UI element as the only guard on
  an admin action — the actual enforcement is the RLS policy plus, for the
  `profiles.role` field specifically, the `prevent_profile_role_escalation`
  trigger (a user cannot promote their own role even via a direct API call).
- **First admin:** still outstanding — see "Supabase project setup" above
  for the exact one-time SQL statement Dan needs to run.

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
- A new table needs **both** an RLS policy (0004-style) and a Data API
  grant (0005-style) to be reachable — see "Supabase project setup." Adding
  one without the other is a common way to ship a table that silently 403s.
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
— not duplicated here to avoid the two files drifting out of sync. Dan's
`.env.local` already has real (non-secret) values from the live Supabase
project; nothing further to configure for local dev.

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
- **"Automatically expose new tables" stays off, and every new table gets
  its own Data API grant.** Don't flip this project setting back on as a
  shortcut — add the grant statement to the table's migration instead (see
  "Supabase project setup").
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
  scored before they joined a given roster. Correct while rosters are set
  once at draft time and don't change, but would need to become a
  time-windowed sum (`added_at` to `removed_at`) if in-season trading is
  ever added.
- **Supabase free-tier project auto-pause after 7 days of inactivity** is a
  real operational quirk for a seasonal app — see COSTS.md. Not a code
  issue, just something Dan needs to remember between seasons.
- **Dan has not yet been promoted to `admin`.** Every admin-gated feature
  (any write to any table) will fail for everyone, including Dan, until the
  one-time promotion SQL statement is run — see "Supabase project setup."
- **GitHub repo is currently Public.** Dan was advised to consider making
  it Private for a family app; his call, not yet changed as of this
  writing.

## Completed functionality

- Project scaffold, environment/config handling, and documentation.
- Full schema design, applied to a live Supabase project (all 5 migrations
  run successfully).
- Working magic-link sign-in, end-to-end, against the real project.

Nothing else user-facing exists yet — no dashboard, no admin tools, no real
show data.

## Recommended next steps

In rough priority order:

1. **Promote Dan to admin** (one SQL statement — see "Supabase project
   setup") — required before any admin-write feature can be tested at all.
2. **Seed Dan's real data.** Use the SQL Editor (no admin UI exists yet) to
   create the *Survivor* and *Traitors* shows, current seasons, contestants,
   and a first league, so there's real data to build UI against.
3. **Minimal admin CRUD** for shows/seasons/contestants/episodes/scoring
   events — even a plain form-based interface — before investing in the
   polished family-facing UI, since Dan needs this to enter real data.
4. **Family-facing read views**: league standings, a roster page, an
   episode scoring breakdown — reading from the views already built.

Do not start any of these without Dan's explicit go-ahead — each phase is
scoped deliberately and stops for review before the next begins, per the
project brief.
