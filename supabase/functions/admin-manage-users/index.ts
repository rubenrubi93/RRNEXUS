// Supabase Edge Function: admin-manage-users
// Deploy with: supabase functions deploy admin-manage-users
// Required secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL"), anonKey = Deno.env.get("SUPABASE_ANON_KEY"), serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return reply({ error: "Server configuration incomplete" }, 500);
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!token) return reply({ error: "Authentication required" }, 401);
  const auth = createClient(url, anonKey, { auth: { persistSession: false } });
  const { data: { user }, error: authError } = await auth.auth.getUser(token);
  if (authError || !user) return reply({ error: "Invalid session" }, 401);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: profile, error: profileError } = await admin.from("user_profiles").select("role").eq("user_id", user.id).maybeSingle();
  if (profileError) return reply({ error: "Could not verify administrator role" }, 500);
  if (profile?.role !== "master_admin") return reply({ error: "Master administrator permission required" }, 403);
  let body: { action?: string; userId?: string; password?: string; role?: string };
  try { body = await req.json(); } catch { return reply({ error: "Invalid JSON" }, 400); }
  if (body.action === "list") {
    const { data: profiles, error } = await admin.from("user_profiles").select("user_id,full_name,role,created_at").order("created_at", { ascending: false });
    if (error) return reply({ error: error.message }, 500);
    const { data: memberships, error: memberError } = await admin.from("company_members").select("user_id,company_id,role,companies(name)");
    if (memberError) return reply({ error: memberError.message }, 500);
    const { data: users, error: usersError } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    if (usersError) return reply({ error: usersError.message }, 500);
    return reply({ users: (profiles || []).map(p => ({
      ...p,
      email: users.users.find(u => u.id === p.user_id)?.email || "",
      memberships: (memberships || []).filter(m => m.user_id === p.user_id).map(m => ({ company_id: m.company_id, role: m.role, company_name: (m as any).companies?.name || "" }))
    })) });
  }
  if (!body.userId) return reply({ error: "userId is required" }, 400);
  if (body.action === "set_password") {
    const password = String(body.password || "");
    if (password.length < 10 || password.length > 72) return reply({ error: "La contraseña debe tener entre 10 y 72 caracteres." }, 400);
    const { error } = await admin.auth.admin.updateUserById(body.userId, { password });
    if (error) return reply({ error: error.message }, 400);
    return reply({ ok: true });
  }
  if (body.action === "set_role") {
    const role = String(body.role || "");
    if (!["client", "consultant", "admin"].includes(role)) return reply({ error: "Rol no válido." }, 400);
    if (body.userId === user.id) return reply({ error: "No puedes cambiar tu propio perfil desde esta pantalla." }, 400);
    const { error } = await admin.from("user_profiles").update({ role }).eq("user_id", body.userId);
    if (error) return reply({ error: error.message }, 400);
    const { error: memberError } = await admin.from("company_members").update({ role }).eq("user_id", body.userId);
    if (memberError) return reply({ error: memberError.message }, 400);
    return reply({ ok: true });
  }
  return reply({ error: "Acción no reconocida." }, 400);
});
