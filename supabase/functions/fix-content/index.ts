// fix-content — the coach checking its own question bank.
//
// Deploy:  supabase functions deploy fix-content
// Secret:  SARVAM_API_KEY (already set)
//
// POST { mode: "scan", limit?: number }  -> { proposals: [...] }   nothing is written
// POST { mode: "apply", items: [...] }   -> { applied: n }         parent approved these
//
// The coach may only ever *propose*. A wrong answer silently corrected is worse
// than a wrong answer left alone, because nobody will look at it again.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `You are checking a maths question bank for a Year 6 olympiad student.
You are given one question and the answer currently stored for it.

Work the question out yourself, carefully, then compare.

Reply with JSON only:
{"verdict":"correct|wrong|missing|unclear",
 "answer":"the right answer, short",
 "method":"the shortest correct route, at most two sentences",
 "why":"one sentence saying what was wrong with the stored answer, or why you are unsure"}

Rules:
- "missing" when there is no stored answer at all.
- "unclear" when the question cannot be answered without a diagram that is not present.
  In that case leave "answer" empty.
- Never mark something wrong unless you are certain. Being unsure is "unclear", not "wrong".`;

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

    const { data: parent } = await asUser.rpc("is_parent");
    if (!parent) return json({ error: "parents only" }, 403);

    const { mode = "scan", limit = 8, items = [] } = await req.json();

    // ---- apply what the parent ticked ------------------------------------
    if (mode === "apply") {
      let n = 0;
      for (const it of items) {
        const { error } = await asUser.rpc("apply_content_fix", {
          p_chapter: it.chapter, p_idx: it.idx,
          p_answer: it.answer ?? "", p_method: it.method ?? "",
          p_reason: it.why ?? "checked by the coach",
        });
        if (!error) n++;
      }
      return json({ applied: n });
    }

    // ---- scan ------------------------------------------------------------
    const { data: suspects } = await asUser.rpc("suspect_questions", { p_limit: Math.min(limit, 12) });
    const proposals: any[] = [];

    for (const s of suspects ?? []) {
      const r = await fetch(ENDPOINT, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
        },
        body: JSON.stringify({
          model: MODEL,
          temperature: 0.1,
          max_tokens: 500,
          messages: [
            { role: "system", content: PROMPT },
            { role: "user", content: `Question: ${s.prompt}\n\nStored answer: ${s.answer_key ?? "(none)"}\nStored method: ${s.method ?? "(none)"}` },
          ],
        }),
      });
      if (!r.ok) continue;
      const body = await r.json();
      const raw = body?.choices?.[0]?.message?.content ?? "";
      let out: any = {};
      try { out = JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1)); } catch { continue; }

      const verdict = String(out.verdict ?? "unclear");
      if (verdict === "correct") continue;

      proposals.push({
        chapter: s.chapter, idx: s.idx,
        prompt: s.prompt,
        was: s.answer_key ?? "",
        answer: String(out.answer ?? "").trim(),
        method: String(out.method ?? "").trim(),
        verdict,
        why: String(out.why ?? "").trim(),
      });
    }

    return json({ proposals, checked: (suspects ?? []).length });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
