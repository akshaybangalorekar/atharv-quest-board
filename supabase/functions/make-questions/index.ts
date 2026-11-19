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
- Stay inside the topic named above. Nothing from another topic, even if it is easier to write.
- Every question must be solvable with Year 6 arithmetic — no algebra beyond a simple unknown, no trigonometry.
- Numbers must be chosen so the answer is clean. Work each one out and check it.
- About one question in three should need a figure — a shape, a grid, a bar chart, a table, a number
  line, a pattern of tiles. For those, add "fig" saying exactly what the drawing must show: every
  length, angle, label and value. The question must be answerable from that drawing alone.
- For the rest, no "fig" key at all.
- Vary the wording. Do not start three questions the same way.
- Keep each question under 40 words.
- About half the questions should be multiple choice. For those add "options": four short choices,
  each one plausible, with EXACTLY ONE correct — and that correct choice must be the same value as "a".
  Wrong options must be believable mistakes, not nonsense. Give the choices in a sensible order, not
  always with the answer first.
- For the rest, no "options" key at all.

Reply with JSON only:
{"rows":[{"q":"the question","a":"the final answer, short","m":"one sentence of method","d":${difficulty},
          "options":["27","32","37","42"],
          "fig":{"what":"a rectangle 8 cm by 5 cm, the left half shaded"}}]}`;

const DRAW = `You are drawing the figure that belongs to a maths question, as an SVG. A student will read
this instead of a page, so it must be right.

Rules:
- viewBox "0 0 480 340". Use the canvas; do not crowd the figure into a corner.
- Colour it: soft fills (#e8f0ff, #fff4d6, #e9f7ec, #fde8ef) with outlines in a darker shade of the same
  colour. Axes and labels #33415c. Three colours at most.
- Line width 2, label font-size 15, font-family="system-ui, sans-serif".
- Label every point, length, angle and value the question names.
- Be geometrically honest: right angles marked with a small square, equal sides equal, bars in
  proportion to their numbers, axes and gridlines present on charts.
- No title, no answer, no workings.

If it cannot be drawn faithfully, reply with exactly: NONE
Otherwise reply with the SVG only, starting with <svg and ending with </svg>.`;

const CHECK = `You check a drawing against the question it belongs to. Answer one word: YES if the drawing shows
every element the question names and nothing false; NO if a label is missing, a number is wrong, a shape
is not what the question says, or a length or angle is clearly out of proportion. Be strict.`;

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
      // every bank that answers for this exam: Edutest is Kilvington and McKinnon,
      // Olympiad is the book and the contest sets, the rest are themselves
      const KINDS: Record<string, string[]> = {
        "AAS numerical reasoning": ["aas"],
        "Edutest numerical reasoning": ["edutest", "elms"],
        "ELMS": ["elms", "edutest"],
        "Olympiad book": ["book", "apsmo"],
        "APSMO Division J": ["apsmo", "book"],
        "ICAS Maths": ["icas"],
        "AMC Upper Primary": ["amc"],
      };
      const kinds = KINDS[exam] ?? [];
      if (kinds.length) {
        // the strand with the fewest questions, so new ones spread rather than pile up
        const { data } = await admin.from("chapters")
          .select("n, title, source, practice").in("source", kinds)
          .order("practice", { ascending: true }).order("n", { ascending: true })
          .limit(1).maybeSingle();
        ch = data;
      }
    }
    if (!ch) return json({ error: "no chapter and no exam I can write for" }, 404);

    const scope = exam
      ? ({
          "AAS numerical reasoning": "Camberwell Grammar's AAS numerical reasoning: number, patterns, money, measurement, simple ratio and data, Year 6 standard",
          "Edutest numerical reasoning": "Edutest as Kilvington sits it: numerical reasoning — series, matrices, arithmetic word problems, quick two-step reasoning",
          "ELMS": "Edutest as McKinnon's ELMS sits it: Year 6 mathematics — number, fractions, measurement, geometry, data",
          "APSMO Division J": "APSMO Division J: five hard olympiad questions, insight over arithmetic, no calculus, no algebra beyond a simple unknown",
          "Olympiad book": "the book's olympiad chapters: counting, logic, number patterns, geometry insight",
          "ICAS Maths": "ICAS Mathematics Paper D: number, measurement, geometry, statistics, straightforward competition style",
          "AMC Upper Primary": "AMC Upper Primary: thirty questions in sixty minutes, 3 to 5 marks, Australian competition style",
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
          { role: "user", content:
            `Topic: ${String(ch.title).split(" · ").pop()} (${ch.title}). ` +
            `This is one of the official topics for this exam. Write ${n} questions inside it.` },
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

    const rows = (parsed.rows ?? [])
      .filter((x: any) => x.q && x.a)
      .map((x: any) => {
        if (!Array.isArray(x.options) || x.options.length < 3) return { ...x, options: undefined };
        const opts = x.options.map((o: unknown) => String(o).trim()).filter(Boolean);
        const ans = String(x.a).trim();
        const hits = opts.filter((o: string) => o === ans
          || o.replace(/^[A-D][).:\s]*/i, "").trim() === ans).length;
        // exactly one correct choice, and it must be the answer we store
        if (opts.length < 3 || hits !== 1) return { ...x, options: undefined };
        return { ...x, options: opts };
      });
    if (!rows.length) return json({ added: 0, difficulty, focus });

    const { data: maxRow } = await admin.from("problems")
      .select("idx").eq("chapter", ch.n).order("idx", { ascending: false }).limit(1).maybeSingle();
    let idx = maxRow?.idx ?? 0;

    let added = 0;
    const drawn: Array<{ chapter: number; idx: number; prompt: string; what: string }> = [];
    for (const row of rows) {
      idx += 1;
      const rowAny = row as any;
      const fig = rowAny?.fig && typeof rowAny.fig === "object" ? rowAny.fig : null;
      if (fig && fig.what) drawn.push({ chapter: ch.n, idx, prompt: String(row.q), what: String(fig.what) });

      const { error } = await admin.from("problems").insert({
        chapter: ch.n, idx, prompt: String(row.q).trim(),
        ...(Array.isArray((row as any).options) ? { options: (row as any).options } : {}),
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

    // a figure for every question that asked for one, checked before it is kept
    let figures = 0;
    for (const item of drawn.slice(0, 8)) {
      const svg = await drawFigure(item.prompt, item.what);
      if (svg) {
        await admin.from("problems").update({ diagram_svg: svg })
          .eq("chapter", item.chapter).eq("idx", item.idx);
        figures += 1;
      }
    }

    return json({ added, figures, difficulty, focus, chapter: ch.n });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

async function ask(messages: unknown[], temperature: number, maxTokens: number) {
  const r = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
    },
    body: JSON.stringify({ model: MODEL, temperature, max_tokens: maxTokens, messages }),
  });
  if (!r.ok) return "";
  const body = await r.json();
  return String(body?.choices?.[0]?.message?.content ?? "");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
