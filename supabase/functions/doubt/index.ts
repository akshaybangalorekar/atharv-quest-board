// doubt — he photographs a question he is stuck on, and it becomes part of the bank.
//
// Deploy:  supabase functions deploy doubt
// Secret:  SARVAM_API_KEY (already set)
//
// POST { path: "<uid>/doubt-....jpg", exam?: "AAS numerical reasoning" }
//   -> { question, answer, method, idea, strand, saved: true, chapter, idx }
//
// Two jobs at once: help him now, and keep the question so it can be taught and
// re-used later. Anything it saves is marked unverified, because it came off a
// photograph.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `This is a photograph of a maths question an 11-year-old could not solve.

Do two things:
1. Read the question as exactly as you can. If part of it is a diagram, describe the diagram in
   words in the question text, in brackets.
2. Solve it. Work it out carefully and check your answer before you write it.

Reply with JSON only:
{"question":"the question, as printed, with any diagram described in brackets",
 "answer":"the final answer, short",
 "method":"the shortest correct route, at most three sentences",
 "idea":"the one thing to notice, in one sentence, that makes it easy",
 "strand":"two or three words naming the topic, e.g. Number series, Ratio, Area",
 "confident":true or false}

Set "confident" to false if the photograph is too unclear to be sure, or if the answer needs a
diagram you cannot see. Never invent a question that is not there.`;

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

    const { path, exam = "AAS numerical reasoning" } = await req.json();
    if (!path) return json({ error: "no photo" }, 400);
    if (!String(path).startsWith(user.id)) return json({ error: "not your photo" }, 403);

    // read the photo
    const bucket = String(path).includes("papers/") ? "papers" : "working";
    const clean = String(path).replace(/^papers\//, "");
    const { data: blob, error: dlErr } = await admin.storage.from(bucket).download(clean);
    if (dlErr || !blob) return json({ error: "could not read the photo" }, 400);

    const buf = new Uint8Array(await blob.arrayBuffer());
    let b64 = "";
    for (let i = 0; i < buf.length; i += 0x8000) {
      b64 += String.fromCharCode(...buf.subarray(i, i + 0x8000));
    }
    b64 = btoa(b64);

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.2,
        max_tokens: 1200,
        messages: [
          { role: "system", content: PROMPT },
          {
            role: "user",
            content: [
              { type: "text", text: "Here is the question." },
              { type: "image_url", image_url: { url: `data:${blob.type || "image/jpeg"};base64,${b64}` } },
            ],
          },
        ],
      }),
    });
    if (!r.ok) return json({ error: "model call failed", detail: await r.text() }, 502);

    const body = await r.json();
    const raw = body?.choices?.[0]?.message?.content ?? "{}";
    let j: any = {};
    try {
      j = JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1));
    } catch {
      return json({ error: "could not read the question clearly" }, 422);
    }
    if (!j.question) return json({ error: "no question found in the photo" }, 422);

    // ---- keep it: file it under that exam, in a strand chapter ----
    const { data: bank } = await admin.from("exam_banks").select("exam, kind, chapter_from, chapter_to").eq("exam", exam).maybeSingle();
    const kind = bank?.kind ?? "aas";
    const strand = String(j.strand ?? "Mixed").slice(0, 40);
    const title = `${exam} · ${strand}`;

    let { data: ch } = await admin.from("chapters").select("n, practice").eq("title", title).maybeSingle();
    if (!ch) {
      const { data: used } = await admin.from("chapters").select("n").eq("source", kind).order("n", { ascending: false }).limit(1).maybeSingle();
      const n = (used?.n ?? (bank?.chapter_from ?? 101) - 1) + 1;
      const { data: made } = await admin.from("chapters")
        .insert({ n, title, examples: 0, practice: 0, tier: 1, source: kind }).select("n, practice").single();
      ch = made;
    }
    if (!ch) return json({ question: j.question, answer: j.answer, method: j.method, idea: j.idea, saved: false });

    const { data: maxRow } = await admin.from("problems")
      .select("idx").eq("chapter", ch.n).order("idx", { ascending: false }).limit(1).maybeSingle();
    const idx = (maxRow?.idx ?? 0) + 1;

    const { error: insErr } = await admin.from("problems").insert({
      chapter: ch.n, idx, prompt: String(j.question).slice(0, 1000),
      difficulty: 3, technique_tags: [strand], source: kind,
    });
    if (!insErr) {
      await admin.from("problem_answers").insert({
        chapter: ch.n, idx,
        answer: `${j.answer ?? ""} — ${j.method ?? ""}`.trim(),
        method: String(j.method ?? "").slice(0, 600),
        answer_key: String(j.answer ?? "").trim() || null,
        mark_mode: j.answer ? "auto" : "manual",
        solved_by: "llm", verified: false,
      });
      await admin.from("exam_map").insert({ exam, chapter: ch.n, idx }).select().maybeSingle();
      await admin.from("chapters").update({ practice: (ch.practice ?? 0) + 1 }).eq("n", ch.n);
    }

    return json({
      question: String(j.question), answer: String(j.answer ?? ""),
      method: String(j.method ?? ""), idea: String(j.idea ?? ""),
      strand, confident: !!j.confident, saved: !insErr,
      chapter: ch.n, idx,
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
