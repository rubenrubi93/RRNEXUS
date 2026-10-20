-- R&R NEXUS CRM — Fase 2: agenda, sesiones y reservas
-- Aditiva e idempotente. Ejecutar en Supabase SQL Editor después de la fase 1.
begin;

create table if not exists public.crm_sessions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  service_id uuid not null,
  staff_id uuid not null,
  location_id uuid,
  session_type text not null check (session_type in ('group','personal')),
  title text not null check (length(trim(title)) between 1 and 160),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null default 1 check (capacity between 1 and 500),
  status text not null default 'scheduled' check (status in ('scheduled','cancelled','completed')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, id),
  foreign key (company_id, service_id) references public.crm_services(company_id,id) on delete restrict,
  foreign key (company_id, staff_id) references public.crm_staff_profiles(company_id,id) on delete restrict,
  foreign key (company_id, location_id) references public.crm_locations(company_id,id) on delete restrict,
  check (ends_at > starts_at),
  check (session_type <> 'personal' or capacity = 1)
);
create index if not exists crm_sessions_company_starts_idx on public.crm_sessions(company_id, starts_at);
create index if not exists crm_sessions_staff_starts_idx on public.crm_sessions(company_id, staff_id, starts_at);
create index if not exists crm_sessions_service_starts_idx on public.crm_sessions(company_id, service_id, starts_at);

create table if not exists public.crm_bookings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  session_id uuid not null,
  client_id uuid not null,
  status text not null default 'booked' check (status in ('booked','cancelled','attended','no_show')),
  booking_notes text,
  booked_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, session_id) references public.crm_sessions(company_id,id) on delete cascade,
  foreign key (company_id, client_id) references public.crm_clients(company_id,id) on delete cascade,
  unique (session_id, client_id)
);
create index if not exists crm_bookings_company_status_idx on public.crm_bookings(company_id,status);
create index if not exists crm_bookings_session_idx on public.crm_bookings(session_id,status);
create index if not exists crm_bookings_client_idx on public.crm_bookings(company_id,client_id,created_at desc);

create or replace function public.crm_check_booking_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  session_capacity integer;
  session_status text;
  session_kind text;
  active_count integer;
  client_user uuid;
begin
  select s.capacity, s.status, s.session_type
    into session_capacity, session_status, session_kind
  from public.crm_sessions s
  where s.id = new.session_id and s.company_id = new.company_id
  for update;
  if not found then raise exception 'La sesión seleccionada no existe.'; end if;
  if session_status <> 'scheduled' then raise exception 'Esta sesión no admite reservas.'; end if;

  select c.user_id into client_user
  from public.crm_clients c
  where c.id = new.client_id and c.company_id = new.company_id;
  if not found then raise exception 'El cliente no pertenece a esta empresa.'; end if;

  if new.status = 'booked' then
    select count(*) into active_count
    from public.crm_bookings b
    where b.session_id = new.session_id and b.status = 'booked'
      and (tg_op = 'INSERT' or b.id <> new.id);
    if active_count >= session_capacity then raise exception 'La sesión está completa.'; end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists crm_booking_capacity_guard on public.crm_bookings;
create trigger crm_booking_capacity_guard
before insert or update of session_id, client_id, status on public.crm_bookings
for each row execute function public.crm_check_booking_capacity();

alter table public.crm_sessions enable row level security;
alter table public.crm_bookings enable row level security;
revoke all on public.crm_sessions, public.crm_bookings from anon;
grant select, insert, update, delete on public.crm_sessions, public.crm_bookings to authenticated;
revoke all on function public.crm_check_booking_capacity() from public, anon, authenticated;

drop policy if exists crm_sessions_read_member on public.crm_sessions;
create policy crm_sessions_read_member on public.crm_sessions for select to authenticated
using (public.crm_has_role(company_id, array['owner','admin','reception','sales','trainer','client']));
drop policy if exists crm_sessions_manage_staff on public.crm_sessions;
create policy crm_sessions_manage_staff on public.crm_sessions for all to authenticated
using (public.crm_has_role(company_id, array['owner','admin','reception','trainer']))
with check (public.crm_has_role(company_id, array['owner','admin','reception','trainer']));

drop policy if exists crm_bookings_read_authorized on public.crm_bookings;
create policy crm_bookings_read_authorized on public.crm_bookings for select to authenticated
using (
  public.crm_has_role(company_id, array['owner','admin','reception','sales','trainer'])
  or exists (
    select 1 from public.crm_clients c
    where c.id = client_id and c.company_id = crm_bookings.company_id and c.user_id = auth.uid()
  )
);
drop policy if exists crm_bookings_create_staff_or_self on public.crm_bookings;
create policy crm_bookings_create_staff_or_self on public.crm_bookings for insert to authenticated
with check (
  public.crm_has_role(company_id, array['owner','admin','reception','sales','trainer'])
  or exists (
    select 1 from public.crm_clients c
    where c.id = client_id and c.company_id = crm_bookings.company_id and c.user_id = auth.uid()
  )
);
drop policy if exists crm_bookings_update_staff on public.crm_bookings;
create policy crm_bookings_update_staff on public.crm_bookings for update to authenticated
using (public.crm_has_role(company_id, array['owner','admin','reception','trainer']))
with check (public.crm_has_role(company_id, array['owner','admin','reception','trainer']));
drop policy if exists crm_bookings_delete_admin on public.crm_bookings;
create policy crm_bookings_delete_admin on public.crm_bookings for delete to authenticated
using (public.crm_has_role(company_id, array['owner','admin']));

commit;

-- Nota: el cliente solo puede crear una reserva de su propia ficha vinculada a auth.users.
-- La ficha debe tener crm_clients.user_id = auth.uid() y membership con rol client.
-- Probar con sesiones grupales y personales, aforo completo, empresas distintas y roles.
