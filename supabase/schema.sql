-- R&R NEXUS multi-tenant baseline for Supabase/Postgres.
-- Apply in Supabase SQL Editor. Review before production use.
create extension if not exists pgcrypto;

create table if not exists public.companies (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 created_at timestamptz not null default now()
);
create table if not exists public.user_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 full_name text,
 role text not null default 'client' check (role in ('master_admin','admin','consultant','client')),
 created_at timestamptz not null default now()
);
create table if not exists public.company_members (
 company_id uuid not null references public.companies(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'client' check (role in ('admin','consultant','client')),
 created_at timestamptz not null default now(),
 primary key(company_id,user_id)
);
create table if not exists public.projects (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 name text not null check (length(name) between 1 and 120),
 status text not null default 'planning' check (status in ('planning','active','completed','on_hold')),
 progress integer not null default 0 check (progress between 0 and 100),
 description text,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.tasks (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 project_id uuid references public.projects(id) on delete cascade,
 title text not null check (length(title) between 1 and 180),
 status text not null default 'todo' check (status in ('todo','in_progress','done')),
 due_date date,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now()
);

create index if not exists company_members_user_idx on public.company_members(user_id);
create index if not exists projects_company_idx on public.projects(company_id);
create index if not exists tasks_company_idx on public.tasks(company_id);

create or replace function public.has_company_role(target_company uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path=public
as $$
 select exists (
  select 1 from public.company_members m
  where m.company_id=target_company and m.user_id=auth.uid() and m.role=any(allowed_roles)
 )
$$;
revoke all on function public.has_company_role(uuid,text[]) from public;
grant execute on function public.has_company_role(uuid,text[]) to authenticated;

alter table public.companies enable row level security;
alter table public.user_profiles enable row level security;
alter table public.company_members enable row level security;
alter table public.projects enable row level security;
alter table public.tasks enable row level security;

drop policy if exists "members read their companies" on public.companies;
create policy "members read their companies" on public.companies for select to authenticated
using (exists(select 1 from public.company_members m where m.company_id=id and m.user_id=auth.uid()));

drop policy if exists "users read own profile" on public.user_profiles;
create policy "users read own profile" on public.user_profiles for select to authenticated using(user_id=auth.uid());

drop policy if exists "users read own memberships" on public.company_members;
create policy "users read own memberships" on public.company_members for select to authenticated using(user_id=auth.uid());

drop policy if exists "members read company projects" on public.projects;
create policy "members read company projects" on public.projects for select to authenticated
using(public.has_company_role(company_id,array['admin','consultant','client']));

drop policy if exists "consultants manage company projects" on public.projects;
create policy "consultants manage company projects" on public.projects for all to authenticated
using(public.has_company_role(company_id,array['admin','consultant']))
with check(public.has_company_role(company_id,array['admin','consultant']));

drop policy if exists "members read company tasks" on public.tasks;
create policy "members read company tasks" on public.tasks for select to authenticated
using(public.has_company_role(company_id,array['admin','consultant','client']));

drop policy if exists "consultants manage company tasks" on public.tasks;
create policy "consultants manage company tasks" on public.tasks for all to authenticated
using(public.has_company_role(company_id,array['admin','consultant']))
with check(public.has_company_role(company_id,array['admin','consultant']));

grant select on public.companies, public.user_profiles, public.company_members, public.projects, public.tasks to authenticated;
grant insert, update, delete on public.projects, public.tasks to authenticated;

-- Provisioning (performed by trusted admin in Supabase, not by the public client):
-- 1. Create a company row.
-- 2. Invite/create auth user in Supabase Auth.
-- 3. Insert user_profiles row with role.
-- 4. Insert company_members row assigning the user to that company and role.
-- 5. Never expose the service_role key in browser code.
