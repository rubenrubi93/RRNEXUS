-- R&R NEXUS: enable a platform-level master administrator.
-- Run in Supabase SQL Editor after deploying this file.
alter table public.user_profiles drop constraint if exists user_profiles_role_check;
alter table public.user_profiles add constraint user_profiles_role_check
  check (role in ('master_admin','admin','consultant','client'));

-- Users may read only their own profile; trusted Edge Functions use service_role
-- for platform administration and must verify the caller's master_admin role.
