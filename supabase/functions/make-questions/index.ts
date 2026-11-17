// make-questions — keeps the bank ahead of him.
//
// Deploy:  supabase functions deploy make-questions
// Secret:  SARVAM_API_KEY (already set)
//
// POST { chapter: number, count?: number }
//   -> { added, difficulty, focus }
//
// It reads what is already in that strand — including anything a parent has
// uploaded — copies the style, steps the difficulty up as he masters it, and
// deliberately varies the question type so he never sees six of the same.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const TYPES = [
  "a number sequence where the rule changes halfway",
  "a coded-word puzzle",
  "a grid or matrix with one missing cell",
  "a money problem with two steps",
  "a ratio or sharing problem",
  "an age problem",
  "a perimeter or area problem",
  "a time or timetable problem",
  "a data question from a small table",
  "a probability question answered as a fraction",
  "a working-backwards problem",
  "a logic puzzle with three or four people and clues",
  "a percentage increase or decrease",
  "a pattern of shapes or matchsticks",
  "a fractions comparison",
];

const PROMPT = (focus: string, difficulty: number, seeds: string) => `You are writing practice questions for an 11-year-old preparing for Australian
maths competitions and scholarship tests.

Write exactly the number asked for. This set must focus on: ${focus}.

Difficulty ${difficulty} of 3 (1 = straightforward, 2 = two steps, 3 = needs a real insight).

${seeds ? `Here are questions already in this strand. Match their style and vocabulary, but do NOT repeat them:\n${seeds}\n` : ""}

Rules:
- Every question must be solvable with Year 6 arithmetic — no algebra beyond a simple unknown, no trigonometry.
- Numbers must be chosen so the answer is clean. Work each one out and check it.
- Never write a question whose answer depends on a diagram you have not drawn.
- Vary the wording. Do not start three questions the same way.
- Keep each question under 40 words.

Reply with JSON only:
{"rows":[{"q":"the question","a":"the final answer, short","m":"one sentence of method","d":${difficulty}}]}`;

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

    const { chapter, count = 6 } = await req.json();
    if (!chapter) return json({ error: "chapter required" }, 400);

    const { data: ch } = await admin.from("chapters")
      .select("n, title, source, practice").eq("n", chapter).single();
    if (!ch) return json({ error: "no such chapter" }, 404);

    // what is already there, as style seeds
    const { data: existing } = await admin.from("problems")
      .select("prompt").eq("chapter", chapter).order("idx").limit(40);
    const seeds = (existing ?? []).slice(-5).map((p) => `- ${p.prompt}`).join("\n");

    // how he is doing in this strand decides the difficulty
    const { data: att } = await admin.from("attempts")
      .select("ok").eq("student_id", user.id).eq("chapter", chapter);
    const tries = (att ?? []).length;
    const right = (att ?? []).filter((a) => a.ok).length;
    const acc = tries ? right / tries : 0;
    let difficulty = 2;
    if (tries >= 6 && acc >= 0.85) difficulty = 3;
    else if (tries >= 4 && acc < 0.5) difficulty = 1;

    const focus = TYPES[Math.floor(Math.random() * TYPES.length)];
    const n = Math.min(Math.max(Number(count) || 6, 1), 10);

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.85,
        max_tokens: 1800,
        messages: [
          { role: "system", content: PROMPT(focus, difficulty, seeds) },
          { role: "user", content: `Strand: ${ch.title}. Write ${n} questions.` },
        ],
      }),
    });
    if (!r.ok) return json({ error: "model call failed", detail: await r.text() }, 502);

    const body = await r.json();
    const raw = body?.choices?.[0]?.message?.content ?? "{}";
    let parsed: { rows?: Array<{ q: string; a: string; m: string; d: number }> } = {};
    try {
      parsed = JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1));
    } catch {
      return json({ error: "the model did not return usable questions" }, 422);
    }

    const rows = (parsed.rows ?? []).filter((x) => x.q && x.a);
    if (!rows.length) return json({ added: 0, difficulty, focus });

    const { data: maxRow } = await admin.from("problems")
      .select("idx").eq("chapter", chapter).order("idx", { ascending: false }).limit(1).maybeSingle();
    let idx = maxRow?.idx ?? 0;

    let added = 0;
    for (const row of rows) {
      idx += 1;
      const { error } = await admin.from("problems").insert({
        chapter, idx, prompt: String(row.q).trim(),
        difficulty: Number(row.d) || difficulty,
        technique_tags: [ch.title.split("·").pop()?.trim() ?? ch.title],
        source: ch.source ?? "book",
      });
      if (error) { idx -= 1; continue; }

      await admin.from("problem_answers").insert({
        chapter, idx,
        answer: `${row.a} — ${row.m ?? ""}`.trim(),
        method: String(row.m ?? "").slice(0, 500),
        answer_key: String(row.a).trim(),
        mark_mode: "auto", solved_by: "llm", verified: false,
      });

      const { data: bank } = await admin.from("exam_banks").select("exam").eq("kind", ch.source ?? "book").maybeSingle();
      if (bank?.exam) {
        await admin.from("exam_map").insert({ exam: bank.exam, chapter, idx }).select().maybeSingle();
      }
      added++;
    }

    await admin.from("chapters").update({ practice: (ch.practice ?? 0) + added }).eq("n", chapter);

    return json({ added, difficulty, focus });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
