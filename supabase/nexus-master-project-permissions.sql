-- R&R NEXUS: allow Master Admin to create/manage projects and tasks across companies.
-- Run once in Supabase > SQL Editor.
-- This does not grant global access to ordinary client accounts.

drop policy if exists "Master admins manage all projects" on public.projects;
create policy "Master admins manage all projects"
on public.projects for all to authenticated
using (exists (
  select 1 from public.user_profiles p
  where p.user_id = auth.uid() and p.role = 'master_admin'
))
with check (exists (
  select 1 from public.user_profiles p
  where p.user_id = auth.uid() and p.role = 'master_admin'
));

drop policy if exists "Master admins manage all tasks" on public.tasks;
create policy "Master admins manage all tasks"
on public.tasks for all to authenticated
using (exists (
  select 1 from public.user_profiles p
  where p.user_id = auth.uid() and p.role = 'master_admin'
))
with check (exists (
  select 1 from public.user_profiles p
  where p.user_id = auth.uid() and p.role = 'master_admin'
));

grant select, insert, update, delete on public.projects, public.tasks to authenticated;
