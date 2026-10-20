-- R&R NEXUS CRM — Fase 1: núcleo multiempresa
-- ADITIVA: no elimina ni modifica las tablas actuales.
-- IMPORTANTE: revisar el esquema real de Supabase y ejecutar primero en un entorno de prueba.
-- Ejecutar desde Supabase SQL Editor solo después de revisar este archivo.
begin;

create extension if not exists pgcrypto;

-- Roles específicos del CRM, separados de los roles históricos de company_members.
create table if not exists public.crm_company_memberships (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','reception','sales','trainer','client')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  primary key (company_id, user_id)
);
create index if not exists crm_company_memberships_user_idx
  on public.crm_company_memberships(user_id, is_active);

create table if not exists public.crm_locations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  address text,
  timezone text not null default 'Europe/Madrid',
  currency char(3) not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, id)
);
create index if not exists crm_locations_company_idx on public.crm_locations(company_id, is_active);

create table if not exists public.crm_staff_profiles (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  full_name text not null check (length(trim(full_name)) between 1 and 160),
  email text,
  phone text,
  specialties text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, id),
  foreign key (company_id, user_id) references public.crm_company_memberships(company_id, user_id) deferrable initially deferred
);
create index if not exists crm_staff_company_idx on public.crm_staff_profiles(company_id, is_active);
create unique index if not exists crm_staff_company_user_unique
  on public.crm_staff_profiles(company_id, user_id) where user_id is not null;

create table if not exists public.crm_clients (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  full_name text not null check (length(trim(full_name)) between 1 and 160),
  email text,
  phone text,
  status text not null default 'lead' check (status in ('lead','active','paused','cancelled','archived')),
  source text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  unique (company_id, id),
  foreign key (company_id, user_id) references public.crm_company_memberships(company_id, user_id) deferrable initially deferred
);
create index if not exists crm_clients_company_status_idx on public.crm_clients(company_id, status);
create index if not exists crm_clients_company_name_idx on public.crm_clients(company_id, full_name);
create unique index if not exists crm_clients_company_user_unique
  on public.crm_clients(company_id, user_id) where user_id is not null;

create table if not exists public.crm_services (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  location_id uuid,
  name text not null check (length(trim(name)) between 1 and 120),
  service_type text not null check (service_type in ('personal_training','semi_private','group_class','assessment','other')),
  duration_minutes integer not null default 60 check (duration_minutes between 5 and 480),
  capacity integer not null default 1 check (capacity between 1 and 500),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, id),
  foreign key (company_id, location_id) references public.crm_locations(company_id, id) on delete restrict
);
create index if not exists crm_services_company_idx on public.crm_services(company_id, is_active);

create table if not exists public.crm_products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 160),
  product_type text not null check (product_type in ('subscription','session_pack','single_session','course','retail','other')),
  description text,
  price_cents bigint not null default 0 check (price_cents >= 0),
  currency char(3) not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  billing_interval text check (billing_interval in ('week','month','year')),
  sessions_included integer check (sessions_included is null or sessions_included > 0),
  validity_days integer check (validity_days is null or validity_days > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, id),
  check (product_type <> 'subscription' or billing_interval is not null)
);
create index if not exists crm_products_company_idx on public.crm_products(company_id, is_active);

-- Helper de autorización CRM. Roles de plataforma master_admin mantienen acceso administrativo.
create or replace function public.crm_has_role(target_company uuid, allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1 from public.user_profiles p
      where p.user_id = auth.uid() and p.role = 'master_admin'
    )
    or exists (
      select 1 from public.crm_company_memberships m
      where m.company_id = target_company
        and m.user_id = auth.uid()
        and m.is_active = true
        and m.role = any(allowed_roles)
    );
$$;
revoke all on function public.crm_has_role(uuid,text[]) from public;
grant execute on function public.crm_has_role(uuid,text[]) to authenticated;

-- RLS en todas las tablas CRM creadas en esta fase.
alter table public.crm_company_memberships enable row level security;
alter table public.crm_locations enable row level security;
alter table public.crm_staff_profiles enable row level security;
alter table public.crm_clients enable row level security;
alter table public.crm_services enable row level security;
alter table public.crm_products enable row level security;

-- Denegar explícitamente acceso anónimo; RLS y grants son controles complementarios.
revoke all on public.crm_company_memberships, public.crm_locations, public.crm_staff_profiles,
  public.crm_clients, public.crm_services, public.crm_products from anon;

drop policy if exists crm_memberships_read_self_or_admin on public.crm_company_memberships;
create policy crm_memberships_read_self_or_admin on public.crm_company_memberships
for select to authenticated
using (user_id = auth.uid() or public.crm_has_role(company_id, array['owner','admin']));

drop policy if exists crm_memberships_manage_admin on public.crm_company_memberships;
create policy crm_memberships_manage_admin on public.crm_company_memberships
for all to authenticated
using (public.crm_has_role(company_id, array['owner','admin']))
with check (public.crm_has_role(company_id, array['owner','admin']));

drop policy if exists crm_locations_read_member on public.crm_locations;
create policy crm_locations_read_member on public.crm_locations
for select to authenticated
using (public.crm_has_role(company_id, array['owner','admin','reception','sales','trainer','client']));

drop policy if exists crm_locations_manage_admin on public.crm_locations;
create policy crm_locations_manage_admin on public.crm_locations
for all to authenticated
using (public.crm_has_role(company_id, array['owner','admin']))
with check (public.crm_has_role(company_id, array['owner','admin']));

drop policy if exists crm_staff_read_company on public.crm_staff_profiles;
create policy crm_staff_read_company on public.crm_staff_profiles
for select to authenticated
using (
  public.crm_has_role(company_id, array['owner','admin','reception','sales'])
  or user_id = auth.uid()
  or public.crm_has_role(company_id, array['trainer'])
);

drop policy if exists crm_staff_manage_admin on public.crm_staff_profiles;
create policy crm_staff_manage_admin on public.crm_staff_profiles
for all to authenticated
using (public.crm_has_role(company_id, array['owner','admin']))
with check (public.crm_has_role(company_id, array['owner','admin']));

drop policy if exists crm_clients_read_authorized on public.crm_clients;
create policy crm_clients_read_authorized on public.crm_clients
for select to authenticated
using (
  user_id = auth.uid()
  or public.crm_has_role(company_id, array['owner','admin','reception','sales'])
);

drop policy if exists crm_clients_create_staff on public.crm_clients;
create policy crm_clients_create_staff on public.crm_clients
for insert to authenticated
with check (public.crm_has_role(company_id, array['owner','admin','reception','sales']));

drop policy if exists crm_clients_update_staff_or_self on public.crm_clients;
drop policy if exists crm_clients_update_authorized_staff on public.crm_clients;
create policy crm_clients_update_authorized_staff on public.crm_clients
for update to authenticated
using (public.crm_has_role(company_id, array['owner','admin','reception','sales']))
with check (public.crm_has_role(company_id, array['owner','admin','reception','sales']));

-- Los clientes solo tienen lectura propia en esta fase.
-- Para editar su perfil se añadirá una operación limitada a columnas permitidas o una función RPC.

drop policy if exists crm_services_read_member on public.crm_services;
create policy crm_services_read_member on public.crm_services
for select to authenticated
using (public.crm_has_role(company_id, array['owner','admin','reception','sales','trainer','client']));

drop policy if exists crm_services_manage_admin on public.crm_services;
create policy crm_services_manage_admin on public.crm_services
for all to authenticated
using (public.crm_has_role(company_id, array['owner','admin']))
with check (public.crm_has_role(company_id, array['owner','admin']));

drop policy if exists crm_products_read_member on public.crm_products;
create policy crm_products_read_member on public.crm_products
for select to authenticated
using (public.crm_has_role(company_id, array['owner','admin','reception','sales','trainer','client']));

drop policy if exists crm_products_manage_admin on public.crm_products;
create policy crm_products_manage_admin on public.crm_products
for all to authenticated
using (public.crm_has_role(company_id, array['owner','admin']))
with check (public.crm_has_role(company_id, array['owner','admin']));

grant select, insert, update, delete on public.crm_company_memberships,
  public.crm_locations, public.crm_staff_profiles, public.crm_clients,
  public.crm_services, public.crm_products to authenticated;

commit;

-- NOTA: las cuentas de empresa deben añadirse a crm_company_memberships explícitamente.
-- No se migran automáticamente los roles históricos: revisar y asignar los roles CRM tras validar el esquema.
-- Antes de producción, probar RLS con dos empresas y roles owner/admin/reception/sales/trainer/client.
