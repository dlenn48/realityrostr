# RealityRostr

Fantasy leagues for reality competition TV — draft contestants from shows
like *Survivor* and *The Traitors*, score them episode by episode, and
compete against your league over a season. Think fantasy football, but for
reality TV.

This repository is currently a **private, family-only MVP** built to replace
a manually maintained scoreboard. It's designed so the same foundation can
grow into a public multi-show, multi-league platform later without a
rewrite — see [CLAUDE.md](./CLAUDE.md) for the full architectural reasoning
and current project status.

## Status

**Phase 1: Foundation.** The app builds and runs, the database schema and
security model are designed, and the project structure is in place. There is
no login, dashboard, or admin UI yet — that starts in Phase 2. See
[CLAUDE.md](./CLAUDE.md#recommended-next-steps) for what's next.

## Technology stack

| Layer | Choice | Why |
|---|---|---|
| Framework | [Next.js](https://nextjs.org) (App Router, TypeScript) | One deployable app for both the family-facing UI and the admin UI; deploys for free on Vercel. |
| Styling | [Tailwind CSS](https://tailwindcss.com) v4 | Fast to build with, no separate design system needed for an MVP. |
| Database & Auth | [Supabase](https://supabase.com) (PostgreSQL) | Free tier covers a small family app entirely; gives us a real relational database, Row Level Security, and authentication without writing a backend. |
| Hosting | [Vercel](https://vercel.com) | Free Hobby tier deploys Next.js directly from GitHub. |
| Source control | GitHub | Private repository, free. |

Every service above is free at this project's current scale. See
[COSTS.md](./COSTS.md) for exactly what each free tier includes, what would
trigger a cost, and migration paths if RealityRostr ever needs to grow past
them.

## Local setup

### Prerequisites

- [Node.js](https://nodejs.org) 20 or later
- A free [Supabase](https://supabase.com) account (for the database)
- A GitHub account (you already have this, since you're reading this from
  the repo)

### 1. Install dependencies

```bash
npm install
```

### 2. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) and create a free account/organization if you don't have one.
2. Create a new project (choose any region close to you; the free tier includes one active project — see COSTS.md).
3. Once it's provisioned, go to **Settings -> API** and note:
   - The **Project URL**
   - The **publishable** (or `anon`) key — safe for the browser
   - The **secret** (or `service_role`) key — server-only, never expose this

### 3. Run the database migrations

In the Supabase dashboard, open the **SQL Editor** and run the files in
`supabase/migrations/` **in order** (0001, then 0002, then 0003, then 0004).
Each file is plain SQL — paste its contents in and click Run. See
[Database setup](#database-setup) below for what each file does.

### 4. Configure environment variables

```bash
cp .env.example .env.local
```

Fill in the three values from step 2. `.env.local` is already git-ignored —
never commit real credentials. See [Required environment variables](#required-environment-variables).

### 5. Run the app

```bash
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000) — you should see a
RealityRostr Phase 1 confirmation page.

## Required environment variables

See `.env.example` for the authoritative, up-to-date list with comments.
Summary:

| Variable | Exposed to browser? | Purpose |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes | Your Supabase project's API URL. |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Yes | Public key for browser/server queries — protected by Row Level Security, not by secrecy. |
| `SUPABASE_SECRET_KEY` | **No** | Server-only key that bypasses Row Level Security. Not used anywhere yet in Phase 1; reserved for a future admin/server action that deliberately needs it. Never prefix a variable like this with `NEXT_PUBLIC_`. |

## Development commands

```bash
npm run dev        # start the local dev server
npm run build      # production build
npm run start      # run a production build locally
npm run lint       # ESLint
npm run typecheck  # TypeScript, no output emitted
```

## General architecture

```
src/
  app/                Next.js App Router pages (currently just the Phase 1 homepage)
  lib/
    supabase/
      client.ts        Supabase client for Client Components (browser)
      server.ts         Supabase client for Server Components / Route Handlers
  types/
    database.ts        Hand-written types mirroring the DB schema (see file header)
supabase/
  migrations/          Numbered, plain-SQL migrations — run manually in the Supabase SQL Editor for now
```

This is intentionally shallow for Phase 1. As real features (auth, admin,
league pages) are built, `src/app` will grow route groups and `src/lib` will
grow feature-specific modules — see CLAUDE.md's conventions section for how
that should be organized as it happens.

## Database setup

The schema is split into four migrations, meant to be run in order:

1. **`0001_core_schema.sql`** — every table (`profiles`, `shows`, `seasons`,
   `contestants`, `leagues`, `league_members`, `rosters`, `roster_entries`,
   `episodes`, `scoring_event_types`, `league_scoring_rules`,
   `scoring_events`), with foreign keys, check constraints, and indexes.
2. **`0002_functions_and_triggers.sql`** — `updated_at` auto-touch triggers,
   an auto-create-profile-on-signup trigger, a guard against a user
   promoting their own role, and the `is_admin()` / `is_league_member()`
   helper functions RLS policies use.
3. **`0003_views.sql`** — the scoring views (`league_effective_scoring_rules`,
   `contestant_episode_points`, `contestant_season_points`,
   `league_standings`, etc.) that compute every point total live, so nothing
   in the schema stores a total that could drift from reality.
4. **`0004_row_level_security.sql`** — enables Row Level Security on every
   table and defines the Phase 1 policy shape: any signed-in family member
   can read everything; only an admin can write anything.

See [CLAUDE.md](./CLAUDE.md#database-architecture) for the full reasoning
behind this design — especially why scoring is modeled as an append-only
ledger rather than stored totals, and why nothing here is Survivor- or
Traitors-specific.

**Once you've run all four migrations**, promote yourself to admin (replace
the email with your own) by running this once in the SQL Editor, after
you've signed up through the app in a later phase:

```sql
update public.profiles set role = 'admin' where email = 'you@example.com';
```

### Regenerating types from a live project

`src/types/database.ts` is hand-written to match the migrations above. Once
your Supabase project exists and has the schema applied, you can regenerate
it for real instead of hand-maintaining it:

```bash
npx supabase gen types typescript --project-id <your-project-id> > src/types/database.ts
```

## Development workflow

- Work in a feature branch, open a pull request into `main` for review (even
  solo, this keeps a clean history and a place for the build/lint checks to
  run before merging).
- Never commit `.env.local` or any real credentials — only `.env.example`
  with placeholder values.
- Schema changes go in a new numbered migration file (e.g.
  `0005_add_something.sql`) — don't edit the existing numbered files once
  they've been run against a real database.
- Keep [CLAUDE.md](./CLAUDE.md) up to date when you make a decision future
  sessions (with Claude or otherwise) will need to know about.
