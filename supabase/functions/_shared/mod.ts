// _shared/mod.ts — every edge function gets its plumbing from here, so a fix lands in all of them.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

export const ok = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "content-type": "application/json" } });

export const fail = (message: string, detail?: unknown, status = 400) =>
  ok({ error: message, detail }, status);

/** one shape for every handler: options, then work, then a readable failure */
export function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    try {
      return await handler(req);
    } catch (e) {
      const msg = String((e as Error)?.message ?? e);
      console.error("handler failed:", msg);
      return fail("the function failed", msg, 500);
    }
  });
}

/** the service client, and the caller, verified once */
export async function context(req: Request) {
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return { error: fail("not signed in", null, 401) } as const;

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const token = auth.replace(/^Bearer\s+/i, "");
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data?.user) return { error: fail("not signed in", null, 401) } as const;

  return { admin, user: data.user, auth } as const;
}

/** whose data this is: the child, or the child this parent looks after */
export async function studentFor(admin: any, userId: string): Promise<string> {
  const { data: own } = await admin.from("profiles").select("student_id").eq("student_id", userId).maybeSingle();
  if (own) return userId;
  const { data: g } = await admin.from("guardians").select("student_id").eq("parent_id", userId).limit(1).maybeSingle();
  return g?.student_id ?? userId;
}

/** the model, called the same way everywhere */
export async function ask(system: string, user: string, temperature = 0, maxTokens = 1200, fn = "ask"): Promise<string> {
  // every call is counted, and a hard daily cap stops a runaway loop before it costs anything
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  try {
    const { data: left } = await admin.rpc("daily_budget_left", { p_cap: 400 });
    if (typeof left === "number" && left <= 0) {
      console.warn("daily model budget reached; refusing the call");
      return "";
    }
  } catch (_) {}
  const r = await fetch("https://api.sarvam.ai/v2/chat/completions", {
    method: "POST",
    headers: { "content-type": "application/json", "api-subscription-key": Deno.env.get("SARVAM_API_KEY")! },
    body: JSON.stringify({
      model: "glm5.3-flash",
      temperature,
      max_tokens: maxTokens,
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
    }),
  });
  if (!r.ok) return "";
  const b = await r.json();
  const out = (b?.choices?.[0]?.message?.content ?? "").trim();
  try {
    // real token counts when the API reports them, characters otherwise
    const u = b?.usage ?? {};
    await admin.rpc("record_usage", {
      p_fn: fn,
      p_in: (system?.length ?? 0) + (user?.length ?? 0),
      p_out: out.length,
      p_tokens_in: Number(u.prompt_tokens ?? 0),
      p_tokens_out: Number(u.completion_tokens ?? 0),
    });
  } catch (_) {}
  return out;
}

/** the first JSON object in a reply, or null */
export function jsonIn(text: string): any | null {
  const m = String(text ?? "").match(/\{[\s\S]*\}/);
  if (!m) return null;
  try { return JSON.parse(m[0]); } catch { return null; }
}
