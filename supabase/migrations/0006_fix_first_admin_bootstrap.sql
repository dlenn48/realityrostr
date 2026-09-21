-- RealityRostr — Fix first-admin bootstrap lockout
-- Run after 0005_data_api_grants.sql.
--
-- Bug: prevent_profile_role_escalation() (from 0002) blocked ANY role
-- change unless the caller was already an admin per auth.uid(). But
-- auth.uid() is null whenever there's no authenticated PostgREST request
-- context — which includes the Supabase SQL Editor, migrations, and any
-- connection using the service_role/secret key. That made it impossible
-- for anyone to ever become the first admin: the very statement meant to
-- create an admin was rejected for not already being run by one.
--
-- Fix: only enforce the check when there IS an authenticated caller
-- (auth.uid() is not null) — i.e. a normal signed-in app user hitting the
-- API. A null auth.uid() means direct database access (SQL Editor,
-- migrations, service_role), which already has unrestricted access
-- regardless of this trigger (that caller could just as easily disable RLS
-- or drop the trigger outright), so gating it here added no real security
-- and only created the lockout.

create or replace function public.prevent_profile_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    if auth.uid() is not null and not exists (
      select 1 from public.profiles where id = auth.uid() and role = 'admin'
    ) then
      raise exception 'Only an admin can change a profile role.';
    end if;
  end if;
  return new;
end;
$$;
