// Supabase Edge Function: admin-create-user
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

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return reply({ error: "Server configuration incomplete" }, 500);

  const authorization = req.headers.get("Authorization") || "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) return reply({ error: "Authentication required" }, 401);

  const authClient = createClient(url, anonKey, { auth: { persistSession: false } });
  const { data: { user }, error: authError } = await authClient.auth.getUser(token);
  if (authError || !user) return reply({ error: "Invalid session" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: profile, error: profileError } = await admin
    .from("user_profiles").select("role").eq("user_id", user.id).maybeSingle();
  if (profileError) return reply({ error: "Could not verify administrator role" }, 500);
  if (profile?.role !== "master_admin") return reply({ error: "Master administrator permission required" }, 403);

  let body: { fullName?: string; email?: string; role?: string; companyName?: string };
  try { body = await req.json(); } catch { return reply({ error: "Invalid JSON" }, 400); }
  const fullName = String(body.fullName || "").trim();
  const email = String(body.email || "").trim().toLowerCase();
  const role = String(body.role || "client");
  const companyName = String(body.companyName || "").trim();
  if (!fullName || fullName.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      !companyName || companyName.length > 160 || !["client", "consultant", "admin"].includes(role)) {
    return reply({ error: "Check name, email, company and role fields" }, 400);
  }

  // Invite the user first; never accept passwords or expose service_role to the browser.
  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name: fullName },
  });
  if (inviteError || !invited.user) return reply({ error: inviteError?.message || "Invitation failed" }, 400);

  const { data: company, error: companyError } = await admin
    .from("companies").insert({ name: companyName }).select("id,name").single();
  if (companyError || !company) {
    await admin.auth.admin.deleteUser(invited.user.id);
    return reply({ error: "Could not create company" }, 500);
  }

  const { error: profileUpsertError } = await admin.from("user_profiles").upsert({
    user_id: invited.user.id, full_name: fullName, role,
  }, { onConflict: "user_id" });
  const { error: memberError } = await admin.from("company_members").insert({
    company_id: company.id, user_id: invited.user.id, role,
  });
  if (profileUpsertError || memberError) {
    await admin.from("company_members").delete().eq("company_id", company.id).eq("user_id", invited.user.id);
    await admin.from("user_profiles").delete().eq("user_id", invited.user.id);
    await admin.from("companies").delete().eq("id", company.id);
    await admin.auth.admin.deleteUser(invited.user.id);
    return reply({ error: "User was invited but setup failed; cleanup attempted. Check function logs." }, 500);
  }
  return reply({ ok: true, email, fullName, role, companyName: company.name, invitationSent: true });
});
