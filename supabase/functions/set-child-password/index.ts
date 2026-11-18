// set-child-password — a parent sets the password of the child they look after.
//
// Deploy:  supabase functions deploy set-child-password
// Secrets: none beyond the standard ones.
//
// POST { student_id?: uuid, password: "..." }
//   -> { ok: true, student: uuid }
//
// The caller must be a guardian of that child. That is checked against the
// guardians table with the service role before anything is changed; a login
// that is not the child's parent gets a 403 and no information.

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

    const { student_id = null, password = "" } = await req.json();
    if (typeof password !== "string" || password.length < 8) {
      return json({ error: "Use at least 8 characters." }, 400);
    }

    // which child: the one asked for, or the only one this parent looks after
    let target = student_id;
    if (!target) {
      const { data: links } = await admin.from("guardians")
        .select("student_id").eq("parent_id", user.id).limit(1);
      target = links?.[0]?.student_id ?? null;
    }
    if (!target) return json({ error: "No child is linked to this login." }, 400);

    // and it must really be theirs
    const { data: mine } = await admin.from("guardians")
      .select("student_id").eq("parent_id", user.id).eq("student_id", target).limit(1);
    if (!mine?.length) return json({ error: "That child is not linked to this login." }, 403);

    const { error } = await admin.auth.admin.updateUserById(target, { password });
    if (error) return json({ error: error.message }, 400);

    // a note in the log, so a password change is never invisible
    await admin.from("account_events").insert({
      student_id: target, by_user: user.id, what: "password set by a parent",
    }).then(() => {}, () => {});

    return json({ ok: true, student: target });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
