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

commit;
