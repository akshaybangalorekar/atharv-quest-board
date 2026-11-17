// solve-questions — works out the answers to questions that have none.
//
// Deploy:  supabase functions deploy solve-questions
// Secret:  SARVAM_API_KEY (already set)
//
// POST { chapter?: number, exam?: string, limit?: number }
//   -> { solved: [{chapter, idx, answer, method, svg, confident}], skipped: n }
//
// Anything it writes is marked solved_by = 'llm' and verified = false, so the
// parent can see which answers did not come from the book. A model's arithmetic
// is not a source of truth; it is a first draft that saves typing.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `You are solving a maths problem for an 11-year-old's question bank.
Work it out carefully. Then reply with JSON only:

{"answer":"the final answer, short — a number, a fraction, or a few words",
 "method":"the shortest correct route, at most two sentences, in plain words",
 "svg":"only if the question needs a diagram: a small self-contained SVG, viewBox 0 0 320 220, no scripts, no external references; otherwise an empty string",
 "confident":true or false}

Rules:
- If you are not certain of the answer, set "confident" to false and say why in "method".
- Never guess a diagram. If a figure is essential and you cannot draw it faithfully, return an empty svg.
- Keep the answer in the form the question asks for: a number, a fraction, a time, a ratio.
- No prose outside the JSON.`;

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

    const { chapter = null, exam = null, limit = 8 } = await req.json();

    // questions with no key, in the requested scope
    let q = admin.from("problems")
      .select("chapter, idx, prompt, chapters(title)")
      .order("chapter").order("idx")
      .limit(Math.min(limit, 20));

    if (chapter) q = q.eq("chapter", chapter);

    const { data: probs, error: pErr } = await q;
    if (pErr) return json({ error: pErr.message }, 500);

    const { data: keys } = await admin.from("problem_answers")
      .select("chapter, idx, answer_key, mark_mode");
    const have = new Set((keys ?? []).filter((k) => k.answer_key).map((k) => `${k.chapter}:${k.idx}`));

    let scoped = (probs ?? []).filter((p) => !have.has(`${p.chapter}:${p.idx}`));
    if (exam) {
      const { data: map } = await admin.from("exam_map").select("chapter, idx").eq("exam", exam);
      const inExam = new Set((map ?? []).map((m) => `${m.chapter}:${m.idx}`));
      scoped = scoped.filter((p) => inExam.has(`${p.chapter}:${p.idx}`));
    }
    scoped = scoped.slice(0, Math.min(limit, 20));

    const solved: any[] = [];
    for (const p of scoped) {
      const r = await fetch(ENDPOINT, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
        },
        body: JSON.stringify({
          model: MODEL,
          temperature: 0.1,
          max_tokens: 700,
          messages: [
            { role: "system", content: PROMPT },
            { role: "user", content: `Chapter: ${p.chapters?.title ?? p.chapter}\nQuestion: ${p.prompt}` },
          ],
        }),
      });
      if (!r.ok) continue;

      const body = await r.json();
      const raw = body?.choices?.[0]?.message?.content ?? "";
      let out: any = {};
      try { out = JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1)); } catch { continue; }
      const answer = String(out.answer ?? "").trim();
      if (!answer) continue;

      await admin.from("problem_answers").upsert({
        chapter: p.chapter, idx: p.idx,
        answer: `${answer} — ${out.method ?? ""}`.trim(),
        method: String(out.method ?? "").slice(0, 600),
        answer_key: answer,
        mark_mode: "auto",
        solved_by: "llm",
        verified: false,
      }, { onConflict: "chapter,idx" });

      if (out.svg && String(out.svg).includes("<svg")) {
        await admin.from("problems").update({ diagram_svg: String(out.svg) })
          .eq("chapter", p.chapter).eq("idx", p.idx);
      }

      solved.push({
        chapter: p.chapter, idx: p.idx, answer,
        method: out.method ?? "", svg: out.svg ? true : false,
        confident: out.confident !== false,
      });
    }

    return json({ solved, skipped: (probs ?? []).length - solved.length });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
