// run-jobs — drain the queue on the server, so closing the tab no longer stops the work.
//
// The page only enqueues and pings. Everything that takes minutes — reading a paper, training on the
// sources, checking the bank — runs here, inside the request, and finishes whether or not the browser
// stays open. Each job is claimed once, so two devices cannot run it twice.

import { serve, ok, context, studentFor } from "./_shared/mod.ts";
import { fillFromMaterial } from "./_shared/generate.ts";

const SUPABASE = Deno.env.get("SUPABASE_URL")!;

serve(async (req) => {
  const ctx = await context(req);
  if ("error" in ctx) return ctx.error;
  const { admin, user } = ctx;
  const student = await studentFor(admin, user.id);

  // claim one queued job: queued -> running, atomically
  const { data: claimed } = await admin.rpc("claim_job", { p_student: student });
  const job = (claimed as any)?.job;
  if (!job) return ok({ ran: null, queued: 0 });

  const detail: Record<string, unknown> = {};
  let failed = false;

  try {
    if (job.kind === "train") {
      detail.train = await callFn("train-coach", { mode: "all" }, req);
    } else if (job.kind === "parse_paper") {
      detail.parse = await parsePaper(admin, student, job.payload?.paper_id, req);
    } else if (job.kind === "verify") {
      detail.verify = await callFn("train-coach", { mode: "verify" }, req);
    } else if (job.kind === "fill") {
      detail.fill = await fillFromMaterial(admin, { perStrand: 3, maxStrands: 6 });
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
