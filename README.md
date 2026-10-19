# R&R NEXUS — Business Platform

Plataforma independiente de **R&R Business & Fitness Consulting** para gestionar oportunidades comerciales, clientes, proyectos de consultoría, tareas e informes.

## Prototipo actual
- Dashboard de actividad.
- CRM de leads y oportunidades.
- Gestión de proyectos y seguimiento de avance.
- Directorio de clientes y previsualización del portal.
- Gestión de tareas.
- Exportación de datos demo a JSON.
- Interfaz responsive con estética dark y acento turquesa `#00D7B7`.

## Ejecutar
Abre `index.html` en un navegador. Esta versión guarda los datos en el almacenamiento local del navegador.

## Importante: estado del producto
Esta entrega es un **prototipo de interfaz**, no un servicio listo para clientes. No incluye autenticación real, backend, base de datos compartida ni aislamiento seguro entre clientes. La vista de portal es una simulación. No introduzcas información confidencial ni datos reales de clientes.

## Siguiente fase recomendada
1. Definir identidad visual definitiva y añadir los assets oficiales del logo.
2. Crear aplicación con autenticación y roles (administrador R&R, consultor y cliente).
3. Configurar base de datos multi-tenant y políticas de acceso por cliente (por ejemplo Supabase Row Level Security).
4. Añadir almacenamiento privado de documentos, auditoría y copias de seguridad.
5. Desplegar en un hosting independiente con dominio propio y configuración de privacidad/GDPR.
6. Probar permisos y aislamiento de datos antes de dar acceso a clientes.

## Independencia
Este repositorio es el hogar de R&R NEXUS y está separado del repositorio de VivaGym. No se deben guardar aquí credenciales, tokens, datos personales reales ni información confidencial.
