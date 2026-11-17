// extract-questions — reads a page of a paper and returns question/answer pairs.
//
// Deploy:  supabase functions deploy extract-questions
// Secret:  SARVAM_API_KEY (already set)
//
// POST { path: "<uid>/file.jpg", exam: "AAS numerical reasoning", strand: "Sequences" }
//   -> { rows: [{ q, a }], note }
//
// The page is a photo or a rendered PDF page already in the `papers` bucket.
// Nothing is written to the question bank here: the parent reviews the rows and
// commits them through add_questions(), so a bad read never lands silently.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT_IMAGE = `This is a page from a school test or workbook. Extract every question on it.

Rules:
- One row per question. Keep the question's own words, shortened to the essentials if it is long.
- If the question has a diagram, say so in the text: "(diagram in the paper)".
- Put the answer in "a" only if the page actually states it, or if it is a plain arithmetic fact
  you are certain of. Otherwise leave "a" as an empty string — it will be marked by hand.
- Never invent a question that is not on the page. Never merge two questions into one.
- Skip headers, instructions, page numbers and marks like "[2]".
- Number the rows in the order they appear.

Reply with JSON only, no prose around it:
{"strand":"two or three words naming the topic, e.g. Sequences, Codes, Venn diagrams, Ratio",
 "rows":[{"q":"...","a":"..."}]}`;

const PROMPT_TEXT = `Below is text taken from a worksheet, a markdown file or a web page of practice
questions. Pull out every question it contains.

Rules:
- One row per question. Keep the question's own words, trimmed to the essentials.
- If an answer is printed next to the question, or follows it in an answer key, put it in "a".
  Otherwise leave "a" as an empty string.
- Do not invent questions. Do not merge two into one. Skip headings, instructions and marks.
- Name the topic in "strand": two or three words, e.g. Sequences, Codes, Ratio, Venn diagrams.

Reply with JSON only:
{"strand":"...","rows":[{"q":"...","a":"..."}]}`;

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

    const { path, text, exam = "", strand = "" } = await req.json();

    let messages: any[];
    let system: string;

    if (text) {
      // a markdown file, an html page, a pasted document — read as words
      system = PROMPT_TEXT;
      messages = [{
        role: "user",
        content: `Exam: ${exam}. Strand hint: ${strand || "work it out"}.\n\n${String(text).slice(0, 60000)}`,
      }];
    } else {
      if (!path) return json({ error: "path or text required" }, 400);
      if (!path.startsWith(user.id + "/")) return json({ error: "not your file" }, 403);

      const { data: file, error: dlErr } = await admin.storage.from("papers").download(path);
      if (dlErr || !file) return json({ error: "could not read the file" }, 404);

      const bytes = new Uint8Array(await file.arrayBuffer());
      let bin = "";
      for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
      const b64 = btoa(bin);
      const mime = file.type || "image/jpeg";

      system = PROMPT_IMAGE;
      messages = [{
        role: "user",
        content: [
          { type: "text", text: `Exam: ${exam}. Strand hint: ${strand || "work it out"}. Extract the questions.` },
          { type: "image_url", image_url: { url: `data:${mime};base64,${b64}` } },
        ],
      }];
    }

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.1,
        max_tokens: 2500,
        messages: [{ role: "system", content: system }, ...messages],
      }),
    });
    if (!r.ok) return json({ error: "model call failed", detail: await r.text() }, 502);

    const body = await r.json();
    const raw = body?.choices?.[0]?.message?.content ?? "{}";
    let parsed: { strand?: string; rows?: Array<{ q: string; a: string }> } = {};
    try {
      parsed = JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1));
    } catch {
      return json({ error: "the page could not be read as questions", detail: raw.slice(0, 400) }, 422);
    }

    const rows = (parsed.rows ?? [])
      .map((x) => ({ q: String(x.q ?? "").trim(), a: String(x.a ?? "").trim() }))
      .filter((x) => x.q.length > 3);

    return json({
      rows,
      strand: (parsed.strand ?? "").trim(),
      note: rows.length
        ? `${rows.length} question${rows.length === 1 ? "" : "s"} read from this page. Check them before adding.`
        : "Nothing that looked like a question on this page.",
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
