# RealityRostr — Cost Assessment

**Bottom line: $0/month beyond the realityrostr.com domain already
purchased.** Every service below has a free tier that comfortably covers a
private app used by a handful of family members. Nothing here requires a
credit card to use at this scale.

This file should be kept accurate as services are added — see
[CLAUDE.md](./CLAUDE.md) for the rule that every new external dependency
gets an entry here before it's adopted.

---

## Supabase (database + authentication)

- **Purpose:** PostgreSQL database, Row Level Security, and user
  authentication.
- **Current tier:** Free.
- **Current cost:** $0.
- **Free-tier limits (as of this writing — verify at [supabase.com/pricing](https://supabase.com/pricing) since these change):**
  - 500 MB database storage
  - 50,000 monthly active users for auth
  - 5 GB bandwidth (egress) / month
  - 1 GB file storage
  - 2 free projects per organization
  - **Free projects pause automatically after 7 days with no API activity.**
    Restoring a paused project is free and takes a couple of minutes from the
    dashboard, but it's a real gotcha for a seasonal app — RealityRostr might
    sit untouched for months between seasons of a show. Plan on manually
    restoring the project each time a new season starts, or on visiting the
    dashboard periodically during the off-season to keep it awake.
  - No point-in-time recovery / automatic backups on the free tier.
- **What could trigger a cost:** Database size approaching 500 MB (extremely
  unlikely for text/relational data at family scale — this would take
  thousands of seasons' worth of scoring events), or wanting automatic
  backups / point-in-time recovery, which start on the $25/month Pro plan.
- **Migration path if RealityRostr grows:** Supabase's Pro plan ($25/month)
  removes the pause-after-inactivity behavior, raises storage/bandwidth
  limits, and adds backups — a straightforward upgrade with no code changes,
  since it's the same database.

## Vercel (hosting)

- **Purpose:** Deploying and hosting the Next.js application.
- **Current tier:** Free (Hobby).
- **Current cost:** $0.
- **Free-tier limits (verify at [vercel.com/pricing](https://vercel.com/pricing)):**
  - Intended for personal, non-commercial use (this project qualifies as a
    private family MVP; revisit this if RealityRostr ever becomes a paid or
    public product).
  - 100 GB/month fast data transfer, 1M edge requests/month, 1M function
    invocations/month — all far beyond what a handful of family members
    checking scores weekly would use.
  - One developer "seat" (i.e., effectively single-account; fine while Dan
    is the only one deploying).
- **What could trigger a cost:** Needing multiple team members with deploy
  access, or the app becoming public/commercial (Hobby's terms don't permit
  that) — either would mean moving to the Pro plan (~$20/month/seat).
- **Migration path if RealityRostr grows:** Vercel Pro is a plan change, not
  a re-architecture — the app deploys the same way either way.

## GitHub (source control)

- **Purpose:** Hosting the private Git repository.
- **Current tier:** Free.
- **Current cost:** $0.
- **Free-tier limits:** Unlimited private repositories on a free personal
  account; this project is a single low-traffic repo, well within any
  reasonable free-tier usage (Actions minutes, if CI is added later, are
  capped on free private repos but not something Phase 1 uses).
- **What could trigger a cost:** Wanting GitHub Actions minutes beyond the
  free allowance (2,000 min/month on free private repos) if CI is added
  later, or moving the repo into a paid GitHub organization/team plan.
- **Migration path if RealityRostr grows:** Move the repository to a
  dedicated GitHub organization (as already anticipated in the project
  brief) — this is a repo transfer, not a code change.

## Domain (realityrostr.com)

- **Purpose:** The application's eventual public URL.
- **Current cost:** Already purchased, tracked separately from application
  operating costs per the project requirements — not counted against the
  $0 operating-cost goal.
- **Ongoing cost:** Annual domain renewal (whatever your registrar charges),
  independent of every service above.

## Explicitly not used (by design)

- **No paid reality-TV data API.** All contestant, episode, and scoring data
  is entered manually through the (future) admin interface. If an API is
  ever considered, it should get its own entry here with a free-tier
  evaluation before being adopted — never added by default.
- **No email service beyond Supabase's built-in auth email.** Supabase's
  free tier includes a low-volume built-in email sender sufficient for
  magic-link sign-in for a handful of family members. If invite/notification
  email volume ever grows meaningfully, that would need its own free-tier
  evaluation (e.g., Resend's free tier) before adding a dependency.

## Review checklist for any new service

Before adding any new external service, dependency, or API to RealityRostr,
document here:

1. What it's used for
2. Why it was selected over alternatives
3. Whether it's currently free, and on what tier
4. The relevant free-tier limitations
5. What usage pattern would push RealityRostr past the free tier
6. What the paid migration path looks like if that happens

Do not add a service that requires a credit card or has usage-based billing
without calling that out explicitly first.
