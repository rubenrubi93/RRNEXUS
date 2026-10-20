# R&R NEXUS CRM — Diseño funcional y técnico (v1)

Estado: propuesta de arquitectura; este documento NO aplica cambios a la base de datos ni modifica la aplicación en producción.

## 1. Objetivo

Añadir a R&R NEXUS un CRM multiempresa orientado inicialmente a estudios boutique y centros de entrenamiento personal. Cada empresa podrá configurar su marca, centros, catálogo de servicios, trabajadores, clientes, agenda, leads y seguimiento comercial. Los clientes dispondrán de un área privada para consultar sus datos y gestionar reservas.

La primera versión usará registro manual de pagos. No procesará tarjetas ni domiciliaciones automáticas.

## 2. Principios de producto

- Integración con la plataforma existente y el proyecto Supabase actual.
- Multiempresa desde el primer día: todas las tablas operativas tienen `company_id`; cuando proceda, también `location_id`.
- Un usuario puede pertenecer a varias empresas y tener un rol distinto en cada una.
- Separar catálogo de precios, contratos/suscripciones, cargos previstos y pagos efectivamente recibidos.
- Mantener historial de reservas, cancelaciones, pagos y cambios relevantes.
- No borrar físicamente movimientos financieros ni registros de asistencia que deban auditarse; usar estados y trazabilidad.
- No recopilar datos de salud innecesarios. Las notas y rutinas sensibles requieren acceso restringido, finalidad clara y controles específicos.
- La autorización debe validarse en la base de datos mediante Supabase Auth y Row Level Security (RLS), no solo ocultando botones en la interfaz.

## 3. Módulos funcionales

### A. Configuración de empresa y centros
- Datos comerciales, logo, zona horaria, moneda (EUR por defecto), políticas de cancelación y ventanas de reserva.
- Uno o varios centros/salas por empresa.
- Horario de apertura, festivos, capacidad de espacios y configuración de reservas.
- Invitación de usuarios y asignación de roles.

### B. Usuarios, clientes y fichas
- Cliente: nombre, email/teléfono, estado, origen, fecha de alta y notas operativas.
- Historial: reservas, asistencia, productos/contratos, cargos, pagos, tareas y comunicaciones.
- Preferencias y consentimientos registrados con fecha y versión del aviso.
- Área privada: próximas reservas, cancelación según política, historial propio y estado de su plan.
- El cliente solo podrá consultar y modificar los campos permitidos de su propio perfil.

### C. Catálogo comercial
- Productos/servicios: cuota periódica, sesión individual, bono de sesiones, entrenamiento semiprivado, clase/curso o producto.
- Nombre, descripción, precio en céntimos (integer) o numeric exacto, moneda, impuestos si aplica, duración, vigencia, número de usos, reglas de renovación y estado.
- Versionar o guardar snapshot del precio en cada contrato/venta; editar el catálogo no altera transacciones históricas.

### D. Suscripciones, bonos y pagos manuales
- Contrato del cliente con fecha de inicio/fin, frecuencia, precio pactado, estado, próxima renovación y motivo de baja.
- Bonos con sesiones incluidas, reservadas, consumidas, caducidad y ajustes trazables.
- Cargos previstos separados de pagos recibidos.
- Pagos manuales: importe, fecha, método, referencia, usuario que registra y estado (registrado, anulado, reembolsado).
- Vencimientos e impagos como alertas; no afirmar que se ha cobrado solo porque exista un cargo.
- Cancelación con fecha efectiva, motivo, registro de solicitud y reglas de preaviso configurables.
- No automatizar cobros bancarios en la primera fase.

### E. Trabajadores y disponibilidad
- Perfil del trabajador vinculado a un usuario de autenticación, especialidades, servicios autorizados y centros asignados.
- Disponibilidad semanal, bloqueos, vacaciones/ausencias y horario laboral.
- Roles: propietario/administrador, recepción, comercial, entrenador y cliente.
- Las reglas de acceso se aplican por empresa y por recurso; el entrenador ve los clientes/sesiones que le correspondan.

### F. Agenda, clases y reservas
- Tipos de sesión: personal, dúo/semiprivada, grupal y evaluación inicial.
- Plantillas recurrentes para clases y sesiones; generar ocurrencias concretas para fechas y horas.
- Reserva con cliente, sesión, entrenador, centro/sala, inicio/fin, estado y origen.
- Estados: reservada, confirmada, asistió, no asistió, cancelada por cliente, cancelada por centro.
- Aforo máximo, lista de espera y control de solapamiento de entrenador/sala.
- Política configurable de cancelación (plazo, penalización o consumo de sesión) y registro de quién canceló/cuándo.
- Las comprobaciones contra dobles reservas y sobreaforo deben realizarse en operaciones de base de datos transaccionales, no solo en frontend.

### G. Leads, tareas y seguimiento
- Lead con fuente, interés, consentimiento/base de contacto, estado, propietario y próximo paso.
- Pipeline configurable: nuevo, contactado, visita/prueba, propuesta, ganado, perdido.
- Tareas: llamada, mensaje, visita, seguimiento, vencimiento; asignado, fecha límite, prioridad y resultado.
- Convertir un lead en cliente sin duplicar la ficha ni perder el historial.

### H. Rutinas y progreso
- Biblioteca de ejercicios y plantillas de rutina.
- Plan asignado a un cliente por un entrenador; ejercicios, series, repeticiones, carga, descanso, observaciones y fechas.
- Seguimiento de sesiones y revisiones.
- En v1 evitar diagnósticos médicos y limitar los datos sensibles. Evaluar cumplimiento normativo y base jurídica antes de añadir medidas de salud, lesiones o datos biométricos.

### I. Informes y NexusAI
- KPI iniciales: leads por etapa, conversión, clientes activos, renovaciones, vencimientos, ingresos registrados, cobros pendientes, ocupación, asistencia, cancelaciones, no-show y sesiones por entrenador.
- Ingresos cobrados deben calcularse desde pagos; ventas/cargos previstos deben mostrarse por separado.
- Integración posterior con NexusAI para analizar tendencias de la empresa autenticada, nunca datos de otra empresa.
- El informe distingue datos reales, estimaciones y recomendaciones.

## 4. Modelo de datos propuesto

Las siguientes son entidades lógicas para diseñar las migraciones. No se deben crear tablas duplicadas sin revisar primero el esquema existente.

### Base actual que se conserva
- `companies`: empresa/tenant.
- `user_profiles`: perfil global de autenticación; revisar su columna role actual antes de ampliar roles.
- `company_members`: relación usuario-empresa; debe evolucionar para soportar roles CRM sin romper los roles actuales.
- `business_metrics`, `sales_entries`, `company_diagnostics`: conservar para el dashboard y análisis financiero.
- `projects`, `tasks`: evaluar reutilización de `tasks` para seguimientos comerciales; añadir campos o tabla específica si los flujos difieren.

### Nuevas entidades propuestas

| Tabla | Propósito / relaciones principales |
|---|---|
| `crm_locations` | Centros/salas por empresa; zona horaria, dirección y estado |
| `crm_staff_profiles` | Perfil profesional asociado a `company_id` y `user_id` |
| `crm_clients` | Ficha de cliente; puede vincularse a un usuario de Auth cuando active el portal |
| `crm_client_consents` | Consentimientos, versión del aviso, fecha y estado |
| `crm_services` | Tipos de sesión, duración, capacidad y requisitos |
| `crm_products` | Catálogo, precio, moneda, tipo y condiciones |
| `crm_memberships` | Contrato/suscripción de cliente, precio pactado, estado y vigencias |
| `crm_packages` | Bono contratado, sesiones incluidas y saldo |
| `crm_package_ledger` | Libro de movimientos de sesiones; consumo, liberación y ajuste con referencia |
| `crm_charges` | Importe previsto o adeudado, vencimiento y estado |
| `crm_payments` | Cobros manuales, método, importe, fecha y usuario registrador |
| `crm_payment_allocations` | Asignación de un pago a uno o varios cargos, si se necesita |
| `crm_staff_availability` | Disponibilidad semanal/bloqueos/ausencias |
| `crm_rooms` | Salas o recursos reservables, capacidad |
| `crm_class_templates` | Plantillas de clases recurrentes |
| `crm_sessions` | Ocurrencia concreta de una clase o sesión, entrenador, sala, aforo |
| `crm_bookings` | Reserva del cliente y estado; sesión, cancelación y asistencia |
| `crm_waitlist` | Cola de espera por sesión, orden y estado |
| `crm_leads` | Oportunidad comercial, fuente, etapa y propietario |
| `crm_activities` | Llamadas, mensajes, visitas y seguimiento ligado a lead/cliente |
| `crm_exercises` | Biblioteca de ejercicios |
| `crm_workout_templates` | Plantillas de rutina |
| `crm_workout_assignments` | Plan asignado a cliente por entrenador y periodo |
| `crm_workout_items` | Ejercicios/series/repeticiones/carga de un plan |
| `crm_audit_log` | Historial de operaciones relevantes, evitando secretos y datos excesivos |

### Reglas de modelado
- Todas las tablas CRM propiedad de una empresa incluirán `company_id NOT NULL`, índices y claves foráneas. Las relaciones entre entidades deberán impedir asociar accidentalmente un cliente de una empresa con una reserva/producto de otra; usar claves únicas compuestas por tenant cuando sea adecuado.
- Dinero: guardar importe exacto y moneda ISO (EUR por defecto); preferir céntimos enteros para importes monetarios sencillos o numeric exacto, nunca float.
- Fechas: usar `timestamptz` para instantes de reserva y auditoría; conservar la zona horaria de la empresa para mostrar agenda y calcular recurrencias.
- Añadir `created_at`, `updated_at`, `created_by` cuando proceda.
- Estados mediante CHECK o tablas de configuración controladas, evitando valores libres inconsistentes.
- Índices por `company_id`, fecha, estado, cliente y trabajador para las consultas habituales.

## 5. Seguridad multiempresa

Supabase Auth autentica a las personas; `company_members` debe ser la fuente de pertenencia y rol por empresa. El perfil global `user_profiles.role` queda reservado para roles de plataforma como `master_admin`, no para determinar el rol de un usuario dentro de cada estudio.

Requisitos:
1. Activar RLS en cada tabla CRM expuesta.
2. Definir políticas de SELECT/INSERT/UPDATE/DELETE por rol y recurso, junto con grants mínimos.
3. Cliente: solo sus datos, reservas, contratos y pagos visibles; nunca los de otros clientes.
4. Entrenador: solo agenda asignada y clientes relacionados con sus sesiones/planes.
5. Recepción/comercial/administrador: acceso según función.
6. El `master_admin` se gestiona de forma explícita y auditable, sin convertir una política de plataforma en acceso público.
7. No exponer la clave `service_role` en frontend.
8. Probar acceso permitido y denegado con dos empresas, dos clientes, un entrenador y un usuario sin sesión. Añadir pruebas automatizadas de RLS antes de producción.

## 6. Pantallas previstas

- Navegación principal: Inicio, Agenda, Clientes, Comercial, Productos y cuotas, Pagos, Equipo, Rutinas, Informes y Configuración.
- Inicio: citas de hoy, tareas vencidas, leads pendientes, próximos vencimientos, cobros pendientes y ocupación.
- Agenda: vistas día/semana, filtros por trabajador/servicio/centro y modal de reserva.
- Cliente: ficha con pestañas Resumen, Reservas, Contrato, Pagos, Rutinas, Historial.
- Área cliente: Próximas reservas, Reservar, Mi plan, Sesiones disponibles, Historial y Perfil.
- Configuración: empresa/centros, servicios, productos, políticas, usuarios y permisos.

## 7. Plan de implementación por fases

### Fase 0 — Auditoría y prototipo
- Revisar el HTML actual, Auth, tablas, políticas RLS y flujo de invitación.
- Definir contratos de datos y navegación; crear prototipo visual sin modificar producción.
- Resultado: alcance aprobado, mapa de pantallas y plan de migración.

### Fase 1 — Núcleo CRM
- Migración versionada y reversible: centros, roles de empresa, clientes, servicios y productos.
- Panel de clientes y catálogo; permisos y aislamiento multiempresa.
- Pruebas RLS con empresas y roles ficticios.

### Fase 2 — Suscripciones y pagos manuales
- Contratos, bonos, cargos, pagos, vencimientos y cancelaciones.
- Libro de movimientos para evitar que una corrección borre el historial.
- Conciliación de los KPI: cobrado, pendiente y previsto claramente separados.

### Fase 3 — Agenda y reservas
- Disponibilidad, sesiones, reservas, cancelación, asistencia, aforo y lista de espera.
- Reglas transaccionales anti-solapamiento y pruebas de concurrencia.
- Vista interna y calendario del cliente.

### Fase 4 — Portal de clientes y equipo
- Acceso de cliente por Supabase Auth, reservas propias, historial y plan.
- Perfiles de trabajadores, roles y agenda asignada.
- Invitaciones seguras, recuperación de contraseña y revocación de accesos.

### Fase 5 — Leads, rutinas e informes
- Pipeline, llamadas/tareas, ejercicios, rutinas, seguimiento y KPI.
- Integración de métricas CRM con dashboard e informes.
- NexusAI con acceso limitado a datos agregados o autorizados de la empresa.

### Fase 6 — Piloto y endurecimiento
- Piloto con una empresa y datos de prueba antes de cargar datos reales.
- Pruebas de permisos, accesibilidad móvil, copias de seguridad, exportación y recuperación.
- Revisar protección de datos, retención, consentimientos y condiciones de servicio antes del lanzamiento.

## 8. Criterios de aceptación del MVP

- Un administrador puede crear servicios, productos, clientes y trabajadores.
- Puede registrar manualmente un pago y ver el vencimiento/saldo correcto.
- Puede programar una sesión y un cliente reservarla desde su área privada.
- La agenda bloquea solapamientos y no permite superar aforo.
- Las cancelaciones siguen la política configurada y actualizan el saldo de sesiones de forma trazable.
- Un cliente no puede ver datos de otro cliente ni de otra empresa, incluso si manipula peticiones API.
- Las cifras de ingresos distinguen cobros reales de cargos pendientes.
- Los roles tienen permisos verificados en backend/RLS y pruebas automatizadas.

## 9. Fuera del primer MVP

- Pasarela de pago, domiciliación y cobro recurrente automático.
- Integración con tornos/acceso físico.
- WhatsApp/SMS automatizados.
- App nativa móvil.
- Facturación fiscal completa y contabilidad.
- Integraciones externas con wearables.
- Diagnóstico médico o gestión clínica.

Estas capacidades se podrán estudiar cuando la base operativa esté validada.

## 10. Compatibilidad con la aplicación actual

La aplicación actual usa HTML/JavaScript y Supabase. Se propone evolucionar de forma incremental, sin reescribir el dashboard financiero ni la función NexusAI existente. Las nuevas tablas y políticas se añadirán en migraciones específicas, manteniendo los nombres y contratos actuales.

Antes de aplicar cualquier SQL se deben comparar los esquemas reales de Supabase con los ficheros del repositorio: los scripts históricos pueden haberse aplicado en un orden diferente. No ejecutar una migración CRM de producción hasta verificar el esquema actual, revisar las políticas y preparar pruebas de rollback.

Referencias de seguridad: documentación oficial de Supabase sobre Row Level Security y protección de datos: https://supabase.com/docs/guides/database/postgres/row-level-security y https://supabase.com/docs/guides/database/secure-data.
