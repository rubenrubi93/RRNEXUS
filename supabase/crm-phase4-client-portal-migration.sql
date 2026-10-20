-- R&R NEXUS CRM — Fase 4: acceso seguro al portal de reservas del cliente
-- Ejecutar en Supabase SQL Editor después de las fases 1, 2 y 3.
begin;

-- El cliente solo puede cancelar su propia reserva; la función de fase 3 aplica el plazo mínimo.
drop policy if exists crm_bookings_cancel_self on public.crm_bookings;
create policy crm_bookings_cancel_self
on public.crm_bookings for update to authenticated
using (
  exists (
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

-- Endurece la política de inserción de reservas propias.
drop policy if exists crm_bookings_create_staff_or_self on public.crm_bookings;
create policy crm_bookings_create_staff_or_self
on public.crm_bookings for insert to authenticated
with check (
  public.crm_has_role(company_id, array['owner','admin','reception','sales','trainer'])
  or (
    status = 'booked'
    and booked_by = (select auth.uid())
    and exists (
      select 1 from public.crm_clients c
      where c.id = crm_bookings.client_id
        and c.company_id = crm_bookings.company_id
        and c.user_id = (select auth.uid())
    )
  )
);


-- Permite al cliente consultar los nombres del equipo activo de su empresa.
drop policy if exists crm_staff_read_client_portal on public.crm_staff_profiles;
create policy crm_staff_read_client_portal
on public.crm_staff_profiles for select to authenticated
using (
  is_active = true
  and public.crm_has_role(company_id, array['client'])
);

-- Devuelve solo disponibilidad agregada de sesiones futuras de la empresa del cliente autenticado.
create or replace function public.crm_client_session_availability(p_company_id uuid)
returns table(session_id uuid, booked_count bigint, session_capacity integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.crm_clients c
    where c.company_id = p_company_id and c.user_id = (select auth.uid())
  ) then
    raise exception 'No tienes acceso a la disponibilidad de esta empresa.';
  end if;

  return query
    select s.id, count(b.id) filter (where b.status = 'booked'), s.capacity
    from public.crm_sessions s
    left join public.crm_bookings b
      on b.company_id = s.company_id and b.session_id = s.id and b.status = 'booked'
    where s.company_id = p_company_id
      and s.status = 'scheduled'
      and s.starts_at > now()
    group by s.id, s.capacity;
end;
$$;
revoke all on function public.crm_client_session_availability(uuid) from public, anon;
grant execute on function public.crm_client_session_availability(uuid) to authenticated;

commit;
