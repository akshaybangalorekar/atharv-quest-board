// make-questions — keeps the bank ahead of him.
//
// Deploy:  supabase functions deploy make-questions
// Secret:  SARVAM_API_KEY (already set)
//
// POST { chapter?: number, exam?: string, count?: number }
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

const PROMPT = (focus: string, difficulty: number, seeds: string, scope: string) => `You are writing practice questions for an 11-year-old preparing for Australian
maths competitions and scholarship tests.

Write exactly the number asked for. This set must focus on: ${focus}.

${scope ? `It must stay inside this exam's scope: ${scope}. Nothing outside that.` : ""}

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

    const { chapter, count = 6, exam = null } = await req.json();

    // an exam can be named instead of a chapter: pick its first strand with room
    let ch: any = null;
    if (chapter) {
      const { data } = await admin.from("chapters")
        .select("n, title, source, practice").eq("n", chapter).single();
      ch = data;
    } else if (exam) {
      const { data: bank } = await admin.from("exam_banks").select("kind").eq("exam", exam).single();
      if (bank) {
        const { data } = await admin.from("chapters")
          .select("n, title, source, practice").eq("source", bank.kind)
          .order("n").limit(1).maybeSingle();
        ch = data;
      }
    }
    if (!ch) return json({ error: "no chapter and no exam I can write for" }, 404);

    const scope = exam
      ? ({
          "AAS numerical reasoning": "numerical reasoning for a Year 6 scholarship test: number, patterns, money, measurement, simple ratio and data",
          "Edutest numerical reasoning": "numerical reasoning: series, matrices, arithmetic word problems, quick two-step reasoning",
          "ELMS": "Year 6 mathematics as McKinnon's ELMS paper sets it: number, fractions, measurement, geometry, data",
          "APSMO Division J": "olympiad problems of the Division J kind: five hard questions, insight over arithmetic, no calculus or algebra beyond a simple unknown",
          "Olympiad book": "the book's olympiad chapters: counting, logic, number patterns, geometry insight",
        } as Record<string, string>)[exam] ?? ""
      : "";

    // style seeds: the uploaded samples first, then whatever is in the strand
    const { data: samples } = await admin.from("problems")
      .select("prompt, paper_id").eq("chapter", ch.n).not("paper_id", "is", null)
      .order("idx", { ascending: false }).limit(6);
    const { data: existing } = await admin.from("problems")
      .select("prompt").eq("chapter", ch.n).order("idx").limit(40);
    const seedRows = (samples?.length ? samples : (existing ?? [])).slice(-6);
    const seeds = seedRows.map((p: any) => `- ${p.prompt}`).join("\n");

    // how he is doing decides the difficulty: accuracy and speed together
    const { data: att } = await admin.from("attempts")
      .select("ok, seconds").eq("student_id", user.id).eq("chapter", ch.n);
    const tries = (att ?? []).length;
    const right = (att ?? []).filter((a: any) => a.ok).length;
    const acc = tries ? right / tries : 0;
    const timed = (att ?? []).filter((a: any) => (a.seconds ?? 0) > 0);
    const speed = timed.length ? timed.reduce((s: number, a: any) => s + a.seconds, 0) / timed.length : 0;

    let difficulty = 2;
    if (tries >= 6 && acc >= 0.85 && (speed === 0 || speed <= 90)) difficulty = 3;   // right and quick
    else if (tries >= 6 && acc >= 0.85) difficulty = 3;                             // right, even if slow
    else if (tries >= 4 && acc < 0.5) difficulty = 1;                               // struggling: easier
    else if (tries >= 4 && acc < 0.7) difficulty = 1;

    const focus = TYPES[Math.floor(Math.random() * TYPES.length)];
    const n = Math.min(Math.max(Number(count) || 6, 1), 20);

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.85,
        max_tokens: 3600,
        messages: [
          { role: "system", content: PROMPT(focus, difficulty, seeds, scope) },
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
      .select("idx").eq("chapter", ch.n).order("idx", { ascending: false }).limit(1).maybeSingle();
    let idx = maxRow?.idx ?? 0;

    let added = 0;
    for (const row of rows) {
      idx += 1;
      const { error } = await admin.from("problems").insert({
        chapter: ch.n, idx, prompt: String(row.q).trim(),
        difficulty: Number(row.d) || difficulty,
        technique_tags: [ch.title.split("·").pop()?.trim() ?? ch.title],
        source: ch.source ?? "book",
      });
      if (error) { idx -= 1; continue; }

      await admin.from("problem_answers").insert({
        chapter: ch.n, idx,
        answer: `${row.a} — ${row.m ?? ""}`.trim(),
        method: String(row.m ?? "").slice(0, 500),
        answer_key: String(row.a).trim(),
        mark_mode: "auto", solved_by: "llm", verified: false,
      });

      const { data: bank } = await admin.from("exam_banks").select("exam").eq("kind", ch.source ?? "book").maybeSingle();
      if (bank?.exam) {
        await admin.from("exam_map").insert({ exam: bank.exam, chapter: ch.n, idx }).select().maybeSingle();
      }
      added++;
    }

    await admin.from("chapters").update({ practice: (ch.practice ?? 0) + added }).eq("n", ch.n);

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
