-- R&R NEXUS CRM — Fase 0: auditoría de solo lectura
-- Ejecutar en Supabase > SQL Editor antes de aplicar crm-phase1-core-migration.sql.
-- No crea, modifica ni elimina objetos. Devuelve el esquema real y las políticas actuales.

-- 1) Columnas de tablas base que el CRM necesita reutilizar.
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'companies','user_profiles','company_members','projects','tasks',
    'business_metrics','sales_entries','company_diagnostics'
  )
order by table_name, ordinal_position;

-- 2) Restricciones actuales (incluye CHECK, claves foráneas y UNIQUE).
select tc.table_name, tc.constraint_name, tc.constraint_type, cc.check_clause
from information_schema.table_constraints tc
left join information_schema.check_constraints cc
  on cc.constraint_schema = tc.constraint_schema
 and cc.constraint_name = tc.constraint_name
where tc.table_schema = 'public'
  and tc.table_name in (
    'companies','user_profiles','company_members','projects','tasks',
    'business_metrics','sales_entries','company_diagnostics'
  )
order by tc.table_name, tc.constraint_type, tc.constraint_name;

-- 3) Estado RLS y políticas existentes.
select c.relname as table_name, c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'companies','user_profiles','company_members','projects','tasks',
    'business_metrics','sales_entries','company_diagnostics'
  )
order by c.relname;

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'companies','user_profiles','company_members','projects','tasks',
    'business_metrics','sales_entries','company_diagnostics'
  )
order by tablename, policyname;

-- 4) Grants de las tablas base para detectar permisos más amplios de lo previsto.
select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'companies','user_profiles','company_members','projects','tasks',
    'business_metrics','sales_entries','company_diagnostics'
  )
order by table_name, grantee, privilege_type;
