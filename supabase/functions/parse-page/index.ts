// parse-page — read one page of a paper, on the server.
//
// Deploy:  supabase functions deploy parse-page
// Secrets: SARVAM_API_KEY (already set)
//
// POST { paper_id: 12, page: 3 }
//   -> { ok: true, added: 6, unanswered: 2, strand: "Geometry" }
//
// The page image is already in storage — the browser put it there at upload
// time, because a browser is the only thing here that can render a PDF. From
// then on the work is here: the model call, the crop of any figure, and the
// writing of the questions. Closing the browser stops nothing; the next call
// picks up the next unfinished page, from any device.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `This is one page from a school test or workbook. Extract every question on it.

Rules:
- One row per question. Keep the question's own words, shortened to the essentials if it is long.
- If it is multiple choice, put the options in "options" as a list of strings exactly as printed,
  and keep them out of the question text.
- If the question has a diagram, keep the words and ALSO give its position on the page in
  "diagram": {"x":0.0,"y":0.0,"w":0.0,"h":0.0} as fractions of the page, top-left corner first.
  Draw the box generously: every label and arrow that belongs to the figure, nothing of the next
  question. Add "kind":"complex" for charts, tables, maps, Venn diagrams, nets; "simple" for one
  plain shape with a couple of labels. Omit "diagram" when there is no figure.
- Put the answer in "a" only if the page states it, or it is a plain arithmetic fact you are sure of.
  Otherwise leave it empty.
- Never invent a question. Never merge two. Skip headers, instructions and marks like "[2]".

Reply with JSON only:
{"strand":"two or three words naming the topic",
 "rows":[{"q":"...","a":"...","options":["A 12","B 18"],
          "diagram":{"x":0.1,"y":0.3,"w":0.6,"h":0.25,"kind":"complex"}}]}`;

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

    const { paper_id, page } = await req.json();
    if (!paper_id || !page) return json({ error: "paper and page required" }, 400);

    const { data: row } = await asUser.from("paper_pages")
      .select("path, done").eq("paper_id", paper_id).eq("page_no", page).maybeSingle();
    if (!row) return json({ error: "no such page" }, 404);

    const { data: paper } = await admin.from("papers")
      .select("id, exam, student_id").eq("id", paper_id).single();
    if (!paper) return json({ error: "no such paper" }, 404);

    // the page image, straight from storage
    const { data: blob, error: dlErr } = await admin.storage.from("papers").download(row.path);
    if (dlErr || !blob) return json({ error: "could not read the page" }, 400);
    const buf = new Uint8Array(await blob.arrayBuffer());
    let bin = "";
    for (let i = 0; i < buf.length; i++) bin += String.fromCharCode(buf[i]);
    const b64 = btoa(bin);

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.1,
        max_tokens: 3000,
        messages: [
          { role: "system", content: PROMPT },
          {
            role: "user",
            content: [
              { type: "text", text: "Extract the questions from this page." },
              { type: "image_url", image_url: { url: `data:image/jpeg;base64,${b64}` } },
            ],
          },
        ],
      }),
    });
    if (!r.ok) return json({ error: "model call failed", detail: await r.text() }, 502);

    const body = await r.json();
    const raw = body?.choices?.[0]?.message?.content ?? "";
    const a = raw.indexOf("{"), b = raw.lastIndexOf("}");
    if (a < 0 || b <= a) return json({ error: "could not read that page" }, 422);

    let parsed: any = {};
    try { parsed = JSON.parse(raw.slice(a, b + 1)); }
    catch { return json({ error: "could not read that page" }, 422); }

    const rows = (parsed.rows ?? [])
      .map((x: any) => {
        const opts = Array.isArray(x.options)
          ? x.options.map((o: unknown) => String(o ?? "").trim()).filter((o: string) => o)
          : [];
        return {
          q: String(x.q ?? "").trim(),
          a: String(x.a ?? "").trim(),
          ...(opts.length >= 2 ? { options: opts } : {}),
          ...(x.diagram && typeof x.diagram === "object" ? { diagram: x.diagram, diagram_kind: String(x.diagram.kind ?? "complex") } : {}),
        };
      })
      .filter((x: any) => x.q.length > 3);

    const strand = String(parsed.strand ?? "").trim() || "General";

    // only someone who may see this child can add to their bank
    const { data: allowed } = await admin.from("guardians")
      .select("student_id").eq("parent_id", user.id).eq("student_id", paper.student_id).limit(1);
    const isSelf = paper.student_id === user.id;
    if (!isSelf && !allowed?.length) return json({ error: "not your child" }, 403);

    const { data: added, error: addErr } = await admin.rpc("add_questions_for", {
      p_student: paper.student_id,
      p_exam: paper.exam,
      p_strand: strand,
      p_rows: rows,
      p_paper: paper_id,
      p_pages: rows.map(() => page),
    });
    if (addErr) return json({ error: addErr.message }, 400);

    await admin.from("paper_pages").update({ done: true })
      .eq("paper_id", paper_id).eq("page_no", page);

    const unanswered = rows.filter((x: any) => !x.a).length;

    // keep this paper's own job up to date, so several papers can be read at once
    const { data: counts } = await admin.from("paper_pages")
      .select("done", { count: "exact" }).eq("paper_id", paper_id);
    const { count: totalPages } = await admin.from("paper_pages")
      .select("*", { count: "exact", head: true }).eq("paper_id", paper_id);
    const { count: donePages } = await admin.from("paper_pages")
      .select("*", { count: "exact", head: true }).eq("paper_id", paper_id).eq("done", true);

    const { data: job } = await admin.from("parse_jobs")
      .select("id, added, unanswered").eq("paper_id", paper_id).eq("status", "running")
      .order("created_at", { ascending: false }).limit(1).maybeSingle();

    if (job) {
      const finished = (donePages ?? 0) >= (totalPages ?? 0);
      await admin.from("parse_jobs").update({
        added: (job.added ?? 0) + (added?.added ?? 0),
        unanswered: (job.unanswered ?? 0) + unanswered,
        strand,
        pages_done: donePages ?? 0,
        pages_total: totalPages ?? 0,
        status: finished ? "done" : "running",
        note: finished
          ? `Questions added to ${strand}. ${(job.added ?? 0) + (added?.added ?? 0)} in all`
            + ((job.unanswered ?? 0) + unanswered > 0 ? `, ${(job.unanswered ?? 0) + unanswered} without an answer yet.` : ".")
          : null,
        updated_at: new Date().toISOString(),
      }).eq("id", job.id);
    }

    return json({ ok: true, added: added?.added ?? 0, improved: added?.improved ?? 0, unanswered, strand, page });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
