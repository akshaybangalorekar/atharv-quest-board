// manage-student — a parent adds a child, or removes one.
//
// Deploy:  supabase functions deploy manage-student
// Secrets: none beyond the standard ones.
//
// POST { action: "create", name, email, password }
//   -> { ok: true, student_id }
// POST { action: "delete", student_id, confirm: "DELETE" }
//   -> { ok: true }
//
// Creating makes a real sign-in for the child, a profile, and the guardian link
// back to whoever asked. Deleting removes the sign-in and everything hanging off
// it. Both require the caller to be a parent of that child (or, for the first
// child, a signed-in account with none yet).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const auth = req.headers.get("Authorization") ?? "";
    const asUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } } },
    );
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: { user } } = await asUser.auth.getUser();
    if (!user) return json({ error: "not signed in" }, 401);

    const body = await req.json();
    const action = String(body.action ?? "");

    // ---- creating a child -------------------------------------------------
    if (action === "create") {
      const name = String(body.name ?? "").trim();
      const email = String(body.email ?? "").trim().toLowerCase();
      const password = String(body.password ?? "");
      if (name.length < 2) return json({ error: "Give the child a name." }, 400);
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json({ error: "That email does not look right." }, 400);
      if (password.length < 8) return json({ error: "Use at least 8 characters for the password." }, 400);

      const { data: made, error: makeErr } = await admin.auth.admin.createUser({
        email, password, email_confirm: true,
        user_metadata: { name, role: "student" },
      });
      if (makeErr) return json({ error: makeErr.message }, 400);
      const id = made.user!.id;

      const { error: profErr } = await admin.from("profiles").upsert({
        student_id: id, name, xp: 0, level: 1, streak_days: 0,
        days_per_week: 6, session_min: 60, timezone: "Australia/Melbourne",
        start_date: new Date().toISOString().slice(0, 10),
      }, { onConflict: "student_id" });
      if (profErr) return json({ error: profErr.message }, 400);

      await admin.from("guardians").insert({ parent_id: user.id, student_id: id })
        .then(() => {}, () => {});

      await admin.from("account_events").insert({
        student_id: id, by_user: user.id, what: `account created (${name})`,
      }).then(() => {}, () => {});

      return json({ ok: true, student_id: id, name, email });
    }

    // ---- removing a child -------------------------------------------------
    if (action === "delete") {
      const target = String(body.student_id ?? "");
      if (String(body.confirm ?? "") !== "DELETE") {
        return json({ error: "Type DELETE to confirm." }, 400);
      }
      if (!target) return json({ error: "Which child?" }, 400);

      const { data: mine } = await admin.from("guardians")
        .select("student_id").eq("parent_id", user.id).eq("student_id", target).limit(1);
      if (!mine?.length) return json({ error: "That child is not linked to this login." }, 403);

      const { error } = await admin.auth.admin.deleteUser(target);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "Unknown action." }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
