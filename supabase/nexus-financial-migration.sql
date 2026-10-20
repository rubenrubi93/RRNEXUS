-- Añade inputs para punto de equilibrio y ventas a R&R NEXUS.
alter table public.business_metrics
  add column if not exists fixed_costs numeric,
  add column if not exists variable_cost_pct numeric;
