// login — sign in with a short name instead of a long email.
//
// Deploy:  supabase functions deploy login
// Secrets: none beyond the ones every function already has.
//
// POST { username: "atharv", password: "…" }
//   -> { access_token, refresh_token, expires_in, token_type }
//
// The email is looked up on the server with the service role and never leaves
// it; the browser only ever receives the session tokens, exactly as it would
// from a normal email sign-in.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const { username, password } = await req.json();
    const name = String(username ?? "").trim();
    if (!name || !password) return json({ error: "Name and password, please." }, 400);

    // a full email still works, so nothing that used to work stops working
    let email = name.includes("@") ? name : null;

    if (!email) {
      const admin = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );
      const { data, error } = await admin.rpc("username_email", { p_name: name });
      if (error) return json({ error: "Could not check that name." }, 500);
      email = data ?? null;
    }

    if (!email) return json({ error: "There is no one called that here." }, 404);

    // swap the name for a session, using the same endpoint the app would call
    const r = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey: Deno.env.get("SUPABASE_ANON_KEY")!,
      },
      body: JSON.stringify({ email, password }),
    });

    const body = await r.json();
    if (!r.ok) {
      const msg = String(body?.error_description ?? body?.msg ?? body?.error ?? "");
      const wrong = /invalid|credential/i.test(msg);
      return json({ error: wrong ? "That name and password do not match." : (msg || "Could not sign in.") }, 401);
    }

    return json({
      access_token: body.access_token,
      refresh_token: body.refresh_token,
      expires_in: body.expires_in,
      token_type: body.token_type,
      email,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
