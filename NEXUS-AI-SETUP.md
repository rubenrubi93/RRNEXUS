# Activar NEXUS AI Analyst

La interfaz del constructor ya incluye NEXUS AI Analyst. Para que responda, la función de Supabase debe desplegarse y necesita una clave de API de OpenAI. La clave **nunca** se debe pegar en `index.html`, `report-builder.html`, `config.js`, GitHub ni en un mensaje de chat.

## 1. Crear la cuenta y el proyecto de API

1. Abre [OpenAI Platform](https://platform.openai.com/).
2. Inicia sesión o crea una cuenta.
3. En el panel de proyectos, crea un proyecto llamado `R&R NEXUS` (o utiliza uno dedicado a esta aplicación).
4. Abre [API Keys](https://platform.openai.com/api-keys) y crea una clave para este proyecto.
5. Guarda la clave en un gestor de contraseñas. OpenAI solo muestra el secreto completo al crearlo.
6. Comprueba la sección de facturación de la API y añade un método de pago o crédito si la cuenta lo requiere. La facturación de API es independiente de ChatGPT. Establece límites de gasto/alertas disponibles en el panel.

## 2. Añadir la clave a Supabase como secreto

1. Abre [Supabase → proyecto RRNEXUS](https://supabase.com/dashboard/project/vlizedcugbpgqszofwup).
2. Entra en **Edge Functions / Secrets** (el nombre de la sección puede variar ligeramente).
3. Añade el secreto con nombre exacto `OPENAI_API_KEY` y como valor la clave que acabas de crear.
4. No añadas esa clave a las variables públicas de la web ni a GitHub.

## 3. Desplegar la Edge Function

Desde un terminal con Supabase CLI instalado y acceso al proyecto:

```bash
supabase login
supabase link --project-ref vlizedcugbpgqszofwup
supabase secrets set OPENAI_API_KEY=tu_clave_api
supabase functions deploy nexus-ai-analyst
```

Sustituye `tu_clave_api` localmente por el secreto real. No guardes el comando con el secreto en scripts, documentos ni repositorios. Si ya has añadido el secreto desde el panel de Supabase, omite la línea `supabase secrets set`.

La función requiere las variables estándar `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` en el entorno de Edge Functions. Supabase normalmente las proporciona al entorno; comprueba la configuración del proyecto si la función indica que falta alguna.

## 4. Probar la IA

1. Abre [R&R NEXUS](https://rubenrubi93.github.io/RRNEXUS/) e inicia sesión.
2. Abre [el constructor de informes](https://rubenrubi93.github.io/RRNEXUS/report-builder.html).
3. Selecciona una empresa y un periodo con métricas guardadas.
4. En NEXUS AI Analyst, pregunta por ejemplo: `Analiza la evolución de ingresos, gastos, coste de personal y EBITDA estimado. Indica qué datos faltan y propón tres acciones prioritarias.`
5. Prueba también con un usuario que no tenga acceso a esa empresa: debe recibir un error de permisos.

## 5. Seguridad antes de uso con clientes

- No compartas claves API; si una clave se expone, revócala y crea otra.
- Mantén las claves en secretos del servidor, nunca en el navegador.
- La función valida la sesión y el acceso a la empresa antes de consultar datos.
- Empieza con un piloto pequeño, revisa el consumo de API y establece límites de gasto.
- Antes de comercializarlo, añade cuotas por usuario/empresa, control de abuso y registros de auditoría; prueba RLS y aislamiento entre empresas.
- La IA puede equivocarse. Verifica cifras y recomendaciones con los datos contables y operativos originales.

## Enlaces oficiales

- [Crear y gestionar claves API](https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key)
- [Inicio rápido de la API](https://developers.openai.com/api/docs/quickstart)
- [Facturación de la API](https://help.openai.com/en/articles/9039756-managing-billing-for-chatgpt-and-the-api-platform)
- [Secretos de Supabase Edge Functions](https://supabase.com/docs/guides/functions/secrets)
