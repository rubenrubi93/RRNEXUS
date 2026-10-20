-- R&R NEXUS: migración del dashboard financiero y registro de ventas.
-- Ejecutar en Supabase SQL Editor después de nexus-management-migration.sql.
alter table public.business_metrics
  add column if not exists fixed_costs numeric,
  add column if not exists variable_cost_pct numeric,
  add column if not exists opening_members integer,
  add column if not exists cash_inflows numeric,
  add column if not exists cash_outflows numeric;

create table if not exists public.sales_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  period date not null,
  sold_at date,
  item_type text not null check (item_type in ('producto','servicio')),
  item_name text not null,
  quantity numeric(12,2) not null default 1 check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists sales_entries_company_period_idx
  on public.sales_entries(company_id, period);
alter table public.sales_entries enable row level security;
drop policy if exists "Sales entries read company and master" on public.sales_entries;
create policy "Sales entries read company and master"
on public.sales_entries for select to authenticated
using (
  exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'master_admin')
  or exists (select 1 from public.company_members m where m.company_id = sales_entries.company_id and m.user_id = auth.uid())
);
drop policy if exists "Sales entries write managers and master" on public.sales_entries;
create policy "Sales entries write managers and master"
on public.sales_entries for all to authenticated
using (
  exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'master_admin')
  or exists (select 1 from public.company_members m where m.company_id = sales_entries.company_id and m.user_id = auth.uid() and m.role in ('admin','consultant'))
)
with check (
  exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'master_admin')
  or exists (select 1 from public.company_members m where m.company_id = sales_entries.company_id and m.user_id = auth.uid() and m.role in ('admin','consultant'))
);
grant select, insert, update, delete on public.sales_entries to authenticated;
