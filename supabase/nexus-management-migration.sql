-- R&R NEXUS: permisos de administración de empresas y base para edición.
-- Ejecutar una sola vez en Supabase > SQL Editor.
-- Las políticas solo conceden acceso global a cuentas con user_profiles.role = 'master_admin'.

drop policy if exists "Master admins read all companies" on public.companies;
create policy "Master admins read all companies"
on public.companies for select to authenticated
using (exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'master_admin'));

drop policy if exists "Master admins update companies" on public.companies;
create policy "Master admins update companies"
on public.companies for update to authenticated
using (exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'master_admin'))
with check (exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'master_admin'));

grant select, update on public.companies to authenticated;

-- Métricas importadas/manuales para el cuadro de mando (por empresa, periodo).
create table if not exists public.business_metrics (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 period date not null,
 revenue numeric(14,2),
 expenses numeric(14,2),
 members integer,
 joiners integer,
 leavers integer,
 payroll numeric(14,2),
 cash_balance numeric(14,2),
 notes text,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 unique(company_id, period)
);
create index if not exists business_metrics_company_period_idx on public.business_metrics(company_id, period desc);
alter table public.business_metrics enable row level security;
drop policy if exists "Company members read business metrics" on public.business_metrics;
create policy "Company members read business metrics" on public.business_metrics for select to authenticated
using (public.has_company_role(company_id,array['admin','consultant','client']) or exists(select 1 from public.user_profiles p where p.user_id=auth.uid() and p.role='master_admin'));
drop policy if exists "Company admins and consultants manage business metrics" on public.business_metrics;
create policy "Company admins and consultants manage business metrics" on public.business_metrics for all to authenticated
using (public.has_company_role(company_id,array['admin','consultant']) or exists(select 1 from public.user_profiles p where p.user_id=auth.uid() and p.role='master_admin'))
with check (public.has_company_role(company_id,array['admin','consultant']) or exists(select 1 from public.user_profiles p where p.user_id=auth.uid() and p.role='master_admin'));
grant select, insert, update, delete on public.business_metrics to authenticated;

create table if not exists public.company_diagnostics (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 title text not null,
 area text not null default 'general',
 finding text not null,
 recommendation text,
 priority text not null default 'medium' check(priority in ('low','medium','high','critical')),
 status text not null default 'open' check(status in ('open','in_progress','resolved')),
 due_date date,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now()
);
alter table public.company_diagnostics enable row level security;
drop policy if exists "Company members read diagnostics" on public.company_diagnostics;
create policy "Company members read diagnostics" on public.company_diagnostics for select to authenticated
using (public.has_company_role(company_id,array['admin','consultant','client']) or exists(select 1 from public.user_profiles p where p.user_id=auth.uid() and p.role='master_admin'));
drop policy if exists "Company managers manage diagnostics" on public.company_diagnostics;
create policy "Company managers manage diagnostics" on public.company_diagnostics for all to authenticated
using (public.has_company_role(company_id,array['admin','consultant']) or exists(select 1 from public.user_profiles p where p.user_id=auth.uid() and p.role='master_admin'))
with check (public.has_company_role(company_id,array['admin','consultant']) or exists(select 1 from public.user_profiles p where p.user_id=auth.uid() and p.role='master_admin'));
grant select, insert, update, delete on public.company_diagnostics to authenticated;
