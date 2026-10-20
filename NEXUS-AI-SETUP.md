# Activar NEXUS AI Analyst con Groq (plan gratuito)

La interfaz del constructor ya incluye NEXUS AI Analyst y la función del servidor está adaptada a Groq. Para que responda, falta crear una clave de Groq, guardarla como secreto en Supabase y desplegar la función. Groq ofrece un plan gratuito con límites de uso; el acceso y los límites exactos dependen del modelo y de la cuenta. Al alcanzar el límite, la IA puede dejar de responder hasta que se restablezca la cuota. Consulta los límites actuales en la consola de Groq.

**Importante:** nunca pegues la clave en `index.html`, `report-builder.html`, `config.js`, GitHub ni en un mensaje de chat.

## 1. Crear la clave gratuita de Groq

1. Abre [Groq Console](https://console.groq.com/).
2. Inicia sesión o crea una cuenta.
3. En el panel de API Keys, genera una clave nueva para R&R NEXUS.
4. Copia y guarda la clave en un gestor de contraseñas. No la compartas.
5. Revisa la sección de límites de uso de tu cuenta y confirma que el modelo `openai/gpt-oss-20b` está disponible para tu plan.

## 2. Añadir la clave a Supabase como secreto

1. Abre [Supabase → proyecto RRNEXUS](https://supabase.com/dashboard/project/vlizedcugbpgqszofwup).
2. Entra en **Edge Functions / Secrets** (el nombre de la sección puede variar).
3. Añade un secreto con nombre exacto `GROQ_API_KEY` y como valor la clave de Groq.
4. No la añadas a las variables públicas de la web ni al repositorio de GitHub.

## 3. Desplegar la Edge Function

Desde un terminal con Supabase CLI instalado y acceso al proyecto:

```bash
supabase login
supabase link --project-ref vlizedcugbpgqszofwup
supabase secrets set GROQ_API_KEY=tu_clave_groq
supabase functions deploy nexus-ai-analyst
```

Sustituye `tu_clave_groq` localmente por el secreto real. No guardes el comando con la clave en scripts, documentos ni repositorios. Si ya añadiste el secreto desde el panel de Supabase, puedes omitir la línea `supabase secrets set`.

La función necesita las variables estándar de Supabase para validar la sesión y consultar los datos. Normalmente están disponibles en el entorno de Edge Functions; si aparece un error de configuración, revisa los logs de la función.

## 4. Probar la IA

1. Abre [R&R NEXUS](https://rubenrubi93.github.io/RRNEXUS/) e inicia sesión.
2. Abre [el constructor de informes](https://rubenrubi93.github.io/RRNEXUS/report-builder.html).
3. Selecciona una empresa y un periodo con métricas guardadas.
4. En NEXUS AI Analyst, prueba: `Analiza la evolución de ingresos, gastos, coste de personal y EBITDA. Indica qué datos faltan y propón tres acciones prioritarias.`
5. Prueba también con un usuario que no tenga acceso a esa empresa: debe recibir un error de permisos.

## 5. Privacidad y seguridad antes de usarlo con clientes

- La clave de Groq se guarda solo en Supabase, nunca en el navegador.
- La función valida la sesión y los permisos de acceso a la empresa antes de consultar sus datos.
- Envía a la IA únicamente los datos necesarios. Antes de usarla con información real de clientes, revisa las condiciones de privacidad y tratamiento de datos de Groq, informa a los clientes cuando corresponda y evita incluir datos personales o secretos.
- Empieza con un piloto pequeño. El plan gratuito tiene límites y no debe considerarse un servicio ilimitado ni una garantía de disponibilidad.
- Antes de comercializarlo, añade cuotas por usuario/empresa, control de abuso y registros de auditoría; prueba RLS y el aislamiento entre empresas.
- La IA puede equivocarse. Verifica las cifras y recomendaciones con los datos contables y operativos originales.

## Enlaces oficiales

- [Groq Console](https://console.groq.com/)
- [Documentación de Groq API](https://console.groq.com/docs/overview)
- [Modelos disponibles](https://console.groq.com/docs/models)
- [API compatible con OpenAI](https://console.groq.com/docs/openai)
- [Secretos de Supabase Edge Functions](https://supabase.com/docs/guides/functions/secrets)
