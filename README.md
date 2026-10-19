# R&R NEXUS — Business Platform

Plataforma de R&R Business & Fitness Consulting para gestionar proyectos, tareas y clientes con espacios de trabajo separados.

## En este repositorio
- `index.html`: interfaz de acceso y dashboard conectado a Supabase.
- `config.js`: configuración pública de Supabase (plantilla; hay que completar).
- `supabase/schema.sql`: esquema inicial multiempresa y políticas RLS.
- `prototype.html`: prototipo original con datos de demostración, conservado como referencia.
- `.github/workflows/pages.yml`: flujo de despliegue estático en GitHub Pages.

## Estado real
La interfaz y el esquema inicial están preparados, pero **el servicio todavía no está operativo**: requiere un proyecto Supabase, aplicar y revisar el SQL, configurar URL y clave publicable, crear usuarios y membresías y activar GitHub Pages. No uses datos reales de clientes ni invites clientes hasta completar y probar estos pasos. El repositorio se ha detectado como público; cámbialo a privado desde Settings si quieres mantener el código fuente privado.

## Puesta en marcha
1. Crea un proyecto Supabase en la organización/cuenta de R&R.
2. En SQL Editor, revisa y aplica `supabase/schema.sql`.
3. Completa `config.js` con Project URL y publishable/anon key. Solo se permite la clave pública con RLS activo; nunca uses `service_role`.
4. En Supabase Auth, configura la URL del sitio y las redirect URLs de GitHub Pages.
5. En Supabase, crea la empresa y usuarios; inserta las filas correspondientes en `user_profiles` y `company_members` usando un proceso de administración de confianza.
6. En GitHub, abre Settings → Pages y selecciona **GitHub Actions** como source. El workflow publicará el sitio al hacer push a `main`.
7. Prueba con dos usuarios de empresas diferentes que no puedan consultar, insertar ni modificar datos de la otra empresa antes de uso real.

## Seguridad y límites
La aplicación utiliza Supabase Auth y espera que RLS proteja cada fila. El SQL es un punto de partida que debe auditarse y probarse antes de producción. Los usuarios cliente pueden leer proyectos/tareas de sus empresas; solo roles admin/consultant pueden gestionarlos. El formulario de creación de proyectos está sujeto a RLS. El portal cliente no debe considerarse listo para producción hasta completar las pruebas de aislamiento, gestión de invitaciones, recuperación de contraseña, registro de auditoría y protección de datos.
