// R&R NEXUS — crea acceso de portal para una ficha CRM existente.
// Configurar SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY como secretos de la Edge Function.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Método no permitido." }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !anon || !service) return reply({ error: "Faltan secretos de configuración en la Edge Function." }, 500);

    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) return reply({ error: "Sesión no válida." }, 401);

    const callerClient = createClient(url, anon, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await callerClient.auth.getUser();
    if (authError || !authData.user) return reply({ error: "Debes iniciar sesión de nuevo." }, 401);
    const caller = authData.user;

    const { client_id, password } = await req.json();
    if (typeof client_id !== "string" || typeof password !== "string" || password.length < 8) {
      return reply({ error: "Indica una ficha válida y una contraseña de al menos 8 caracteres." }, 400);
    }

    const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: profile } = await admin.from("user_profiles").select("role").eq("user_id", caller.id).maybeSingle();
    const isMaster = profile?.role === "master_admin";

    const { data: client, error: clientError } = await admin
      .from("crm_clients")
      .select("id,company_id,full_name,email,user_id")
      .eq("id", client_id)
      .maybeSingle();
    if (clientError || !client) return reply({ error: "No se encuentra la ficha del cliente." }, 404);
    if (!client.email || !client.email.includes("@")) return reply({ error: "La ficha necesita un correo electrónico válido." }, 400);
    if (client.user_id) return reply({ error: "Esta ficha ya está vinculada a una cuenta. No se ha creado otra." }, 409);

    if (!isMaster) {
      const { data: membership } = await admin.from("company_members")
        .select("role")
        .eq("company_id", client.company_id)
        .eq("user_id", caller.id)
        .maybeSingle();
      if (!membership || !["owner", "admin"].includes(membership.role)) {
        return reply({ error: "Solo el administrador de la empresa puede crear accesos de clientes." }, 403);
      }
    }

    const { data: existing } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    if (existing?.users?.some((u) => u.email?.toLowerCase() === client.email.toLowerCase())) {
      return reply({ error: "Ya existe una cuenta con ese correo. Vincúlala desde el flujo de administración en lugar de crear otra." }, 409);
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: client.email,
      password,
      email_confirm: true,
      user_metadata: { full_name: client.full_name, account_type: "client_portal" },
    });
    if (createError || !created.user) return reply({ error: createError?.message || "No se pudo crear la cuenta." }, 400);

    const { error: linkError } = await admin.from("crm_clients").update({ user_id: created.user.id })
      .eq("id", client.id).eq("company_id", client.company_id);
    if (linkError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return reply({ error: "No se pudo vincular la cuenta a la ficha: " + linkError.message }, 500);
    }

    const { error: roleError } = await admin.from("company_members").upsert({
      company_id: client.company_id, user_id: created.user.id, role: "client",
    }, { onConflict: "company_id,user_id" });
    if (roleError) {
      await admin.from("crm_clients").update({ user_id: null }).eq("id", client.id);
      await admin.auth.admin.deleteUser(created.user.id);
      return reply({ error: "No se pudo asignar el rol de cliente: " + roleError.message }, 500);
    }

    return reply({ ok: true, client_id: client.id, user_id: created.user.id });
  } catch (e) {
    return reply({ error: e instanceof Error ? e.message : "Error interno." }, 500);
  }
});

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
