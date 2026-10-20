-- R&R NEXUS CRM — Fase 3: reglas de reserva por cliente
-- Migración aditiva e idempotente. Ejecutar en Supabase SQL Editor tras Fases 1 y 2.
begin;

alter table public.crm_clients
  add column if not exists weekly_booking_limit integer not null default 3
    check (weekly_booking_limit between 0 and 100),
  add column if not exists booking_window_days integer not null default 7
    check (booking_window_days between 1 and 90),
  add column if not exists cancellation_cutoff_hours integer not null default 2
    check (cancellation_cutoff_hours between 0 and 168),
  add column if not exists waitlist_enabled boolean not null default true;

comment on column public.crm_clients.weekly_booking_limit is
  'Máximo de reservas por semana; 0 significa sin límite. Las reservas realizadas cuentan.';
comment on column public.crm_clients.booking_window_days is
  'Número máximo de días de antelación para reservar.';
comment on column public.crm_clients.cancellation_cutoff_hours is
  'Horas mínimas antes del inicio para que el cliente pueda cancelar.';
comment on column public.crm_clients.waitlist_enabled is
  'Indica si el cliente puede apuntarse a listas de espera.';

-- Lista de espera por sesión, con aislamiento por empresa.
create table if not exists public.crm_waitlist (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  session_id uuid not null,
  client_id uuid not null,
  status text not null default 'waiting'
    check (status in ('waiting','promoted','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, session_id)
    references public.crm_sessions(company_id,id) on delete cascade,
  foreign key (company_id, client_id)
    references public.crm_clients(company_id,id) on delete cascade,
  unique (session_id, client_id)
);
create index if not exists crm_waitlist_session_status_idx
  on public.crm_waitlist(session_id, status, created_at);
create index if not exists crm_waitlist_client_idx
  on public.crm_waitlist(company_id, client_id, status);

alter table public.crm_waitlist enable row level security;
revoke all on public.crm_waitlist from anon;
grant select, insert, update, delete on public.crm_waitlist to authenticated;

drop policy if exists crm_waitlist_read_staff_or_self on public.crm_waitlist;
create policy crm_waitlist_read_staff_or_self
on public.crm_waitlist for select to authenticated
using (
  public.crm_has_role(company_id, array['owner','admin','reception','sales','trainer'])
  or exists (
    select 1 from public.crm_clients c
    where c.id = crm_waitlist.client_id
      and c.company_id = crm_waitlist.company_id
      and c.user_id = (select auth.uid())
  )
);

drop policy if exists crm_waitlist_join_self on public.crm_waitlist;
create policy crm_waitlist_join_self
on public.crm_waitlist for insert to authenticated
with check (
  exists (
    select 1 from public.crm_clients c
    where c.id = crm_waitlist.client_id
      and c.company_id = crm_waitlist.company_id
      and c.user_id = (select auth.uid())
      and c.waitlist_enabled = true
  )
  and exists (
    select 1 from public.crm_sessions s
    where s.id = crm_waitlist.session_id
      and s.company_id = crm_waitlist.company_id
      and s.status = 'scheduled'
      and s.starts_at > now()
  )
);

create or replace function public.crm_validate_waitlist_entry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_waitlist_enabled boolean;
  v_window_days integer;
  v_starts_at timestamptz;
  v_capacity integer;
  v_status text;
  v_booked_count integer;
begin
  select c.user_id, c.waitlist_enabled, c.booking_window_days
    into v_user_id, v_waitlist_enabled, v_window_days
  from public.crm_clients c
  where c.id = new.client_id and c.company_id = new.company_id;

  if not found or v_user_id is distinct from (select auth.uid()) then
    raise exception 'Solo puedes apuntarte a la lista de espera de tu propia ficha.';
  end if;
  if not v_waitlist_enabled then
    raise exception 'La lista de espera no está habilitada para tu cuenta.';
  end if;

  select s.starts_at, s.capacity, s.status
    into v_starts_at, v_capacity, v_status
  from public.crm_sessions s
  where s.id = new.session_id and s.company_id = new.company_id
  for update;

  if not found or v_status <> 'scheduled' then
    raise exception 'La sesión no está disponible para lista de espera.';
  end if;
  if v_starts_at <= now() or v_starts_at > now() + make_interval(days => v_window_days) then
    raise exception 'La sesión está fuera de tu ventana de reserva (% días).', v_window_days;
  end if;

  select count(*) into v_booked_count
  from public.crm_bookings b
  where b.session_id = new.session_id and b.status = 'booked';
  if v_booked_count < v_capacity then
    raise exception 'La sesión todavía tiene plazas; puedes reservar directamente.';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists crm_waitlist_entry_guard on public.crm_waitlist;
create trigger crm_waitlist_entry_guard
before insert on public.crm_waitlist
for each row execute function public.crm_validate_waitlist_entry();
revoke all on function public.crm_validate_waitlist_entry() from public, anon, authenticated;

drop policy if exists crm_waitlist_update_staff on public.crm_waitlist;
create policy crm_waitlist_update_staff
on public.crm_waitlist for update to authenticated
using (public.crm_has_role(company_id, array['owner','admin','reception','trainer']))
with check (public.crm_has_role(company_id, array['owner','admin','reception','trainer']));

-- Reemplaza la validación de reservas: capacidad + ventana + cuota semanal.
-- Las reglas por cliente se aplican cuando reserva el propio cliente; el personal puede reservar en su nombre.
create or replace function public.crm_check_booking_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_capacity integer;
  v_session_status text;
  v_starts_at timestamptz;
  v_client_user uuid;
  v_weekly_limit integer;
  v_window_days integer;
  v_active_count integer;
  v_week_count integer;
begin
  select s.capacity, s.status, s.starts_at
    into v_capacity, v_session_status, v_starts_at
  from public.crm_sessions s
  where s.id = new.session_id and s.company_id = new.company_id
  for update;

  if not found then raise exception 'La sesión seleccionada no existe.'; end if;
  if v_session_status <> 'scheduled' then
    raise exception 'Esta sesión no admite reservas.';
  end if;

  select c.user_id, c.weekly_booking_limit, c.booking_window_days
    into v_client_user, v_weekly_limit, v_window_days
  from public.crm_clients c
  where c.id = new.client_id and c.company_id = new.company_id;

  if not found then raise exception 'El cliente no pertenece a esta empresa.'; end if;

  if new.status = 'booked' and v_client_user is not null
     and v_client_user = (select auth.uid()) then
    if v_starts_at <= now() then
      raise exception 'No puedes reservar una sesión que ya ha comenzado.';
    end if;
    if v_starts_at > now() + make_interval(days => v_window_days) then
      raise exception 'Esta sesión está fuera de tu ventana de reserva (% días).', v_window_days;
    end if;

    if v_weekly_limit > 0 then
      -- Serializa reservas del mismo cliente y semana para evitar superar el límite con peticiones simultáneas.
      perform pg_advisory_xact_lock(
        hashtextextended(
          new.client_id::text || ':' || date_trunc('week', v_starts_at)::text,
          0
        )
      );
      select count(*) into v_week_count
      from public.crm_bookings b
      join public.crm_sessions s on s.id = b.session_id
        and s.company_id = b.company_id
      where b.company_id = new.company_id
        and b.client_id = new.client_id
        and b.status in ('booked','attended','no_show')
        and date_trunc('week', s.starts_at) = date_trunc('week', v_starts_at)
        and (tg_op = 'INSERT' or b.id <> new.id);
      if v_week_count >= v_weekly_limit then
        raise exception 'Has alcanzado tu límite de % reservas para esa semana.', v_weekly_limit;
      end if;
    end if;
  end if;

  if new.status = 'booked' then
    select count(*) into v_active_count
    from public.crm_bookings b
    where b.session_id = new.session_id
      and b.status = 'booked'
      and (tg_op = 'INSERT' or b.id <> new.id);
    if v_active_count >= v_capacity then
      raise exception 'La sesión está completa.';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

-- Los clientes solo pueden actualizar su propia reserva para cancelarla.
drop policy if exists crm_bookings_cancel_self on public.crm_bookings;
create policy crm_bookings_cancel_self
on public.crm_bookings for update to authenticated
using (
  status = 'booked'
  and exists (
    select 1 from public.crm_clients c
    where c.id = crm_bookings.client_id
      and c.company_id = crm_bookings.company_id
      and c.user_id = (select auth.uid())
  )
)
with check (
  status = 'cancelled'
  and exists (
    select 1 from public.crm_clients c
    where c.id = crm_bookings.client_id
      and c.company_id = crm_bookings.company_id
      and c.user_id = (select auth.uid())
  )
);

create or replace function public.crm_validate_client_booking_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_client_user uuid;
  v_cutoff_hours integer;
  v_starts_at timestamptz;
begin
  if old.status = 'booked' and new.status = 'cancelled' then
    select c.user_id, c.cancellation_cutoff_hours
      into v_client_user, v_cutoff_hours
    from public.crm_clients c
    where c.id = old.client_id and c.company_id = old.company_id;

    select s.starts_at into v_starts_at
    from public.crm_sessions s
    where s.id = old.session_id and s.company_id = old.company_id;

    if v_client_user = (select auth.uid())
       and v_starts_at < now() + make_interval(hours => v_cutoff_hours) then
      raise exception 'Solo puedes cancelar hasta % horas antes del inicio.', v_cutoff_hours;
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists crm_booking_client_rules on public.crm_bookings;
create trigger crm_booking_client_rules
before update of status on public.crm_bookings
for each row execute function public.crm_validate_client_booking_update();

revoke all on function public.crm_validate_client_booking_update() from public, anon, authenticated;

commit;

-- Valores por defecto para clientes existentes y nuevos: 3 reservas/semana,
-- ventana 7 días, cancelación 2 horas antes y lista de espera habilitada.
-- El límite semanal cuenta reservas booked, attended y no_show de la semana de la sesión;
-- las canceladas no consumen cuota. Las reservas administrativas no se limitan por la cuota personal.
