-- RealityRostr — Functions & triggers
-- Run after 0001_core_schema.sql.

-- ---------------------------------------------------------------------------
-- set_updated_at(): generic "touch" trigger for every table with an
-- updated_at column.
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_shows_updated_at before update on public.shows
  for each row execute function public.set_updated_at();
create trigger trg_seasons_updated_at before update on public.seasons
  for each row execute function public.set_updated_at();
create trigger trg_contestants_updated_at before update on public.contestants
  for each row execute function public.set_updated_at();
create trigger trg_leagues_updated_at before update on public.leagues
  for each row execute function public.set_updated_at();
create trigger trg_rosters_updated_at before update on public.rosters
  for each row execute function public.set_updated_at();
create trigger trg_episodes_updated_at before update on public.episodes
  for each row execute function public.set_updated_at();
create trigger trg_scoring_event_types_updated_at before update on public.scoring_event_types
  for each row execute function public.set_updated_at();
create trigger trg_league_scoring_rules_updated_at before update on public.league_scoring_rules
  for each row execute function public.set_updated_at();
create trigger trg_scoring_events_updated_at before update on public.scoring_events
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- handle_new_user(): auto-create a profiles row whenever someone completes
-- Supabase Auth signup. Runs as security definer so it can insert into
-- profiles despite RLS. New profiles always start as 'member' — see
-- README.md / CLAUDE.md for the one-time step to promote the first admin.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- prevent_profile_role_escalation(): a user may update their own profile
-- (display name, avatar) but may not change their own `role`. Only an
-- existing admin may promote/demote a role. This is enforced here, as a
-- trigger, rather than folded into the RLS UPDATE policy, because RLS policy
-- expressions can't cleanly compare NEW.role to OLD.role.
-- ---------------------------------------------------------------------------
create or replace function public.prevent_profile_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    if not exists (
      select 1 from public.profiles where id = auth.uid() and role = 'admin'
    ) then
      raise exception 'Only an admin can change a profile role.';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_prevent_profile_role_escalation
  before update on public.profiles
  for each row execute function public.prevent_profile_role_escalation();

-- ---------------------------------------------------------------------------
-- sync_roster_entry_league_id(): populates roster_entries.league_id from the
-- roster's league membership, so the app never has to (and can't get it
-- wrong). See 0001's comment on roster_entries.league_id for why this
-- denormalization exists.
-- ---------------------------------------------------------------------------
create or replace function public.sync_roster_entry_league_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select lm.league_id into new.league_id
  from public.rosters r
  join public.league_members lm on lm.id = r.league_member_id
  where r.id = new.roster_id;

  if new.league_id is null then
    raise exception 'Could not resolve league_id for roster_id %', new.roster_id;
  end if;

  return new;
end;
$$;

create trigger trg_sync_roster_entry_league_id
  before insert or update of roster_id on public.roster_entries
  for each row execute function public.sync_roster_entry_league_id();

-- ---------------------------------------------------------------------------
-- is_admin(): true if the currently-authenticated user is a site admin.
-- security definer so it can read profiles regardless of the caller's own
-- RLS visibility — this is the standard Supabase pattern for avoiding
-- recursive RLS checks.
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

-- ---------------------------------------------------------------------------
-- is_league_member(): true if the currently-authenticated user belongs to
-- the given league. Not used by any Phase 1 policy yet (family MVP policies
-- below grant read access to all authenticated users), but provided now so
-- Phase 2+ can tighten league visibility without a migration.
-- ---------------------------------------------------------------------------
create or replace function public.is_league_member(target_league_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.league_members
    where league_id = target_league_id and profile_id = auth.uid()
  );
$$;
