// run-jobs — drain the queue on the server, so closing the tab no longer stops the work.
//
// The page only enqueues and pings. Everything that takes minutes — reading a paper, training on the
// sources, checking the bank — runs here, inside the request, and finishes whether or not the browser
// stays open. Each job is claimed once, so two devices cannot run it twice.

import { serve, ok, context, studentFor } from "./_shared/mod.ts";
import { fillFromMaterial } from "./_shared/generate.ts";
import { alignExam, scopeExam } from "./_shared/authority.ts";
import { gateExam, gateQuestion } from "./_shared/gate.ts";

const SUPABASE = Deno.env.get("SUPABASE_URL")!;

serve(async (req) => {
  const ctx = await context(req);
  if ("error" in ctx) return ctx.error;
  const { admin, user } = ctx;
  const student = await studentFor(admin, user.id);

  // a single question, checked right before it is presented
  let body: any = {};
  try { body = await req.json(); } catch (e) { console.error("run-jobs step failed:", String((e as Error)?.message ?? e)); }
  if (body?.mode === "one") {
    const { data: q } = await admin.from("problems")
      .select("chapter, idx, prompt, options, gate_at").eq("chapter", body.chapter).eq("idx", body.idx).maybeSingle();
    if (!q) return ok({ error: "no such question" }, 404);

    const { data: se } = await admin.rpc("strand_exam", { p_chapter: q.chapter });
    const exam = (se as any)?.exam ?? "olympiad";
    const fresh = q.gate_at && (Date.now() - new Date(q.gate_at).getTime() < 7 * 86400000);
    if (fresh && body.force !== true) return ok({ cached: true, gate_state: (se as any)?.gate_state ?? null });

    const { data: ans } = await admin.from("problem_answers")
      .select("answer_key").eq("chapter", q.chapter).eq("idx", q.idx).maybeSingle();
    const { data: material } = await admin.rpc("authority_material", { p_exam: exam, p_limit: 5 });
    const official = (material ?? []).map((x: any) => String(x.body ?? "")).join("\n\n").slice(0, 3000);
    const hasOfficial = !!(await admin.rpc("exam_has_official", { p_exam: exam }))?.data;

    const verdict = await gateQuestion(admin, { ...q, answer: ans?.answer_key }, official, hasOfficial);
    await admin.from("problems").update({
      gate_state: verdict.state, gate_at: new Date().toISOString(), gate_note: verdict.why || null,
    }).eq("chapter", q.chapter).eq("idx", q.idx);

    return ok({ gate_state: verdict.state, why: verdict.why, exam, official: hasOfficial });
  }

  // claim one queued job: queued -> running, atomically
  const { data: claimed } = await admin.rpc("claim_job", { p_student: student });
  const job = (claimed as any)?.job;
  if (!job) return ok({ ran: null, queued: 0 });

  const detail: Record<string, unknown> = {};
  let failed = false;

  try {
    if (job.kind === "ingest" || job.kind === "train") {
      // 1 keep what has arrived  2 read the sources  3 write questions  4 check them
      // 5 align to official material  6 gate what is left, so nothing is served unchecked
      detail.train = await callFn("train-coach", { mode: "all" }, req);
      for (const ex of ["aas", "edutest", "amc", "icas", "olympiad"]) {
        const { data: hasOfficial } = await admin.rpc("exam_has_official", { p_exam: ex });
        // align first: a rewritten question must be gated after the rewrite, never before
        if (hasOfficial) detail["align_" + ex] = await alignExam(admin, ex, { limit: 10 });
        detail["gate_" + ex] = await gateExam(admin, ex, { limit: 20 });
      }
    } else if (job.kind === "parse_paper") {
      detail.parse = await parsePaper(admin, student, job.payload?.paper_id, req);
      const { data: paper } = await admin.from("papers").select("exam").eq("id", job.payload?.paper_id).maybeSingle();
      const key = String(paper?.exam ?? "").toLowerCase();
      const ex = key.includes("edutest") || key.includes("elms") ? "edutest"
        : key.includes("aas") ? "aas" : key.includes("icas") ? "icas"
        : key.includes("amc") ? "amc" : "olympiad";
      detail.gate = await gateExam(admin, ex, { limit: 25 });
    } else if (job.kind === "verify") {
      detail.verify = await callFn("train-coach", { mode: "verify" }, req);
      for (const ex of ["aas", "edutest", "amc", "icas", "olympiad"]) {
        detail["gate_" + ex] = await gateExam(admin, ex, { limit: 25 });
      }
    } else if (String(job.kind).startsWith("scope:")) {
      // a question written from the web must still be on the exam's topic list
      detail.scope = await scopeExam(admin, String(job.kind).split(":")[1], { limit: 40 });
    } else if (String(job.kind).startsWith("align:")) {
      // Top Scope material arrived: every question for that exam is reviewed against it
      const exam = String(job.kind).split(":")[1];
      detail.align = await alignExam(admin, exam, { limit: 25 });
      detail.verify = await callFn("train-coach", { mode: "verify" }, req);
      detail.gate = await gateExam(admin, exam, { limit: 40 });   // official material just arrived
    } else if (String(job.kind).startsWith("gate:")) {
      // the last check before anything is served
      const exam = String(job.kind).split(":")[1];
      detail.gate = await gateExam(admin, exam, { limit: 40 });
    } else if (job.kind === "fill") {
      detail.fill = await fillFromMaterial(admin, { perStrand: 3, maxStrands: 6 });
      for (const ex of ["aas", "edutest", "amc", "icas", "olympiad"]) {
        detail["gate_" + ex] = await gateExam(admin, ex, { limit: 15 });
      }
    } else {
      detail.skipped = `unknown job kind ${job.kind}`;
    }
  } catch (e) {
    failed = true;
    detail.error = String((e as Error)?.message ?? e);
  }

  await admin.rpc("finish_job", { p_id: job.id, p_ok: !failed, p_detail: detail, p_error: failed ? String(detail.error ?? "") : null });
  const { data: left } = await admin.from("jobs").select("id").eq("student_id", student).eq("status", "queued");
  return ok({ ran: job.kind, id: job.id, failed, detail, queued: (left ?? []).length });
});

/** call another edge function as the same person, and return its JSON */
async function callFn(name: string, body: unknown, req: Request) {
  const r = await fetch(`${SUPABASE}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: req.headers.get("authorization") ?? "",
    },
    body: JSON.stringify(body),
  });
  try { return await r.json(); } catch { return { status: r.status }; }
}

/** read a paper page by page until there are none left */
async function parsePaper(admin: any, student: string, paperId: number | string, req: Request) {
  let pages = 0, added = 0, held = 0;
  for (let i = 0; i < 40; i++) {
    const { data: next } = await admin.rpc("next_parse_page", { p_paper: paperId });
    const page = (next as any)?.page ?? (next as any)?.page_no ?? null;
    if (!page) break;

    const res = await callFn("parse-page", { paper_id: paperId, page }, req);
    if (res?.error) throw new Error(String(res.error));
    pages++;
    added += Number(res?.added ?? 0);
    held += Number(res?.held_back ?? 0);
  }
  return { pages, added, held };
}
