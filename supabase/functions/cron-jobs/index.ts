// cron-jobs — the sweep the database calls on a timer. No person needed.
//
// verify_jwt is off because the caller is pg_cron, which has no user token. It is not open: the body
// must carry the drain token that lives in app_config, which is readable by nobody but this function's
// service role. It works through every student with queued work, one job each, then returns.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { fillFromMaterial } from "./_shared/generate.ts";
import { gateExam, gateQuestion } from "./_shared/gate.ts";
import { checkQuestion } from "./_shared/quality.ts";
import { ask } from "./_shared/mod.ts";
import { alignExam } from "./_shared/authority.ts";

const SUPABASE = Deno.env.get("SUPABASE_URL")!;
const ADMIN = () => createClient(SUPABASE, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const EXAMS = ["aas", "edutest", "amc", "icas", "olympiad"];

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  let body: any = {};
  try { body = await req.json(); } catch (e) { console.error("cron-jobs step failed:", String((e as Error)?.message ?? e)); }

  const admin = ADMIN();

  // the token is the only key: it is not a user token and it is not guessable
  const { data: expected } = await admin.rpc("drain_token");
  if (!expected || body?.token !== expected) {
    return json({ error: "not allowed" }, 403);
  }

  // is the model answering at all? A gate that cannot reach the model must say so, not reject silently
  if (body?.mode === "ping") {
    const r = await fetch("https://api.sarvam.ai/v2/chat/completions", {
      method: "POST",
      headers: { "content-type": "application/json", "api-subscription-key": Deno.env.get("SARVAM_API_KEY") ?? "" },
      body: JSON.stringify({ model: "sarvam-m", temperature: 0, max_tokens: 20,
        messages: [{ role: "user", content: "Reply with the single word: ready" }] }),
    });
    const text = await r.text();
    return json({ status: r.status, keyPresent: !!Deno.env.get("SARVAM_API_KEY"), body: text.slice(0, 300) });
  }

  // draw the figures: questions that name a drawing get one, and it is checked before it is kept
  if (body?.mode === "draw") {
    const limit = Number(body?.limit ?? 5);
    // the drawer needs to know whose work this is
    const { data: owner } = await admin.from("profiles").select("student_id").limit(1).maybeSingle();
    const ownerId = body?.student ?? owner?.student_id ?? "";
    const FIG = /venn|angle|perimeter|area|net\b|graph|chart|shape|symmetr|coordinate|triangle|rectangle|circle|number line/i;
    const { data: all } = await admin.from("problems")
      .select("chapter, idx, prompt, diagram_svg, status")
      .is("diagram_svg", null)
      .in("status", ["cleared", "provisional"])
      .limit(60);
    const { data: strands } = await admin.from("strands").select("n, title");
    const titleOf = new Map((strands ?? []).map((x: any) => [x.n, String(x.title)]));

    // a drawing belongs only to a topic that needs one, or to a question that names one
    const rows = (all ?? []).filter((q: any) =>
      FIG.test(String(titleOf.get(q.chapter) ?? "")) ||
      /\b(diagram|figure|shown below|the picture|the table)\b/i.test(String(q.prompt))
    ).slice(0, limit);

    const drawn: any[] = [];
    for (const q of rows ?? []) {
      const res = await callFn("draw-figure", { chapter: q.chapter, kind: "question", idx: q.idx, question: q.prompt }, ownerId);
      drawn.push({ chapter: q.chapter, idx: q.idx, ok: !!res?.svg, checked: res?.checked ?? false,
                   note: res?.error ?? "", head: String(q.prompt).slice(0, 60) });
    }
    return json({ attempted: (rows ?? []).length, drawn });
  }

  // the online-question checker: is each question in the strand it belongs to, and is it sound?
  if (body?.mode === "audit") {
    const limit = Number(body?.limit ?? 30);
    const { data: rows } = await admin.from("problems")
      .select("chapter, idx, prompt, options, status").order("chapter").limit(limit);
    const { data: strands } = await admin.from("strands").select("n, title, exam_id");
    const { data: exams } = await admin.from("exams").select("id, key");
    const examOf = new Map((exams ?? []).map((e: any) => [e.id, e.key]));
    const titleOf = new Map((strands ?? []).map((x: any) => [x.n, x.title]));

    const findings: any[] = [];
    for (const q of rows ?? []) {
      const own = titleOf.get(q.chapter) ?? "";
      const examId = (strands ?? []).find((x: any) => x.n === q.chapter)?.exam_id;
      const siblings = (strands ?? []).filter((x: any) => x.exam_id === examId).map((x: any) => x.title);

      // is it answerable at all?
      const verdict = await checkQuestion(String(q.prompt), false);

      // does it belong where it is?
      let best = own, belongs = true;
      if (siblings.length > 1) {
        const pick = await ask(
          `You file practice questions under a topic. Here are the topics for this exam:\n${siblings.join("\n")}`,
          `Question: ${q.prompt}\n\nReply with JSON only: {"topic":"one topic from the list, copied exactly"}`,
          0, 200, "audit");
        const m = String(pick).match(/\{[\s\S]*\}/);
        if (m) {
          try {
            const parsed = JSON.parse(m[0]);
            best = String(parsed.topic ?? own);
            belongs = best.trim().toLowerCase() === own.trim().toLowerCase();
          } catch (e) { console.error("cron-jobs step failed:", String((e as Error)?.message ?? e)); }
        }
      }

      findings.push({ chapter: q.chapter, idx: q.idx, exam: examOf.get(examId) ?? "?", strand: own,
                      sound: verdict.ok, why: verdict.why, in_right_strand: belongs,
                      suggested: belongs ? own : best, head: String(q.prompt).slice(0, 70) });
    }

    const wrong = findings.filter((f) => !f.in_right_strand);
    const unsound = findings.filter((f) => !f.sound);
    return json({ audited: findings.length, wrong_strand: wrong.length, unsound: unsound.length,
                  findings, wrong, unsound });
  }

  // golden questions: the judgement itself, tested against the live model
  if (body?.mode === "selftest") {
    const cases = [
      { q: "Tom has 3 more marbles than Sam. How many does Tom have?", expect: "failed", why: "Sam's count is never given" },
      { q: "A rectangle is 4 cm by 6 cm. What is its area?", expect: "provisional", why: "complete and answerable" },
      { q: "Look at the diagram below. What is the marked angle?", expect: "failed", why: "no diagram is supplied" },
      { q: "What is 15% of 80?", expect: "provisional", why: "complete and answerable" },
      { q: "A bag has some red and blue counters. What fraction are red?", expect: "failed", why: "no numbers at all" },
    ];
    const results = [];
    for (const c of cases) {
      const v = await gateQuestion(admin, { chapter: 0, idx: 0, prompt: c.q, options: null }, "", false);
      results.push({ q: c.q.slice(0, 60), expected: c.expect, got: v.state, ok: v.state === c.expect, why: v.why });
    }
    return json({ selftest: results, passed: results.filter((r) => r.ok).length, of: results.length });
  }

  // a run whose request died is not work in progress
  try { await admin.rpc("reap_stuck_jobs"); } catch (e) { console.error("reap failed:", String((e as Error)?.message ?? e)); }

  const { data: students } = await admin.rpc("students_with_queued");
  const ran: any[] = [];

  for (const student of (students ?? []).slice(0, 5)) {
    const { data: claimed } = await admin.rpc("claim_job", { p_student: student });
    const job = (claimed as any)?.job;
    if (!job) continue;

    const detail: Record<string, unknown> = {};
    let failed = false;

    try {
      if (job.kind === "ingest" || job.kind === "train") {
        detail.train = await callFn("train-coach", { mode: "all" }, student);
        for (const ex of EXAMS) {
          detail["gate_" + ex] = await gateExam(admin, ex, { limit: 20 });
          const { data: hasOfficial } = await admin.rpc("exam_has_official", { p_exam: ex });
          if (hasOfficial) detail["align_" + ex] = await alignExam(admin, ex, { limit: 10 });
        }
      } else if (String(job.kind).startsWith("gate:")) {
        detail.gate = await gateExam(admin, String(job.kind).split(":")[1], { limit: 40 });
      } else if (String(job.kind).startsWith("align:")) {
        const ex = String(job.kind).split(":")[1];
        detail.align = await alignExam(admin, ex, { limit: 25 });
        detail.gate = await gateExam(admin, ex, { limit: 40 });
      } else if (job.kind === "fill") {
        detail.fill = await fillFromMaterial(admin, { perStrand: 3, maxStrands: 6 });
        for (const ex of EXAMS) detail["gate_" + ex] = await gateExam(admin, ex, { limit: 15 });
      } else if (job.kind === "parse_paper") {
        detail.parse = await parsePaper(admin, student, job.payload?.paper_id);
      } else if (job.kind === "verify") {
        for (const ex of EXAMS) detail["gate_" + ex] = await gateExam(admin, ex, { limit: 25 });
      } else {
        detail.skipped = `unknown job kind ${job.kind}`;
      }
    } catch (e) {
      failed = true;
      detail.error = String((e as Error)?.message ?? e);
    }

    await admin.rpc("finish_job", {
      p_id: job.id, p_ok: !failed, p_detail: detail,
      p_error: failed ? String(detail.error ?? "") : null,
    });
    ran.push({ student, kind: job.kind, ok: !failed });
  }

  const { data: left } = await admin.rpc("students_with_queued");
  return json({ ran, stillQueued: (left ?? []).length });
});

async function callFn(name: string, body: unknown, student: string) {
  const { data: token } = await ADMIN().rpc("drain_token");
  const r = await fetch(`${SUPABASE}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
      "x-quest-student": student,
      "x-quest-drain": token ?? "",
    },
    body: JSON.stringify(body),
  });
  try { return await r.json(); } catch { return { status: r.status }; }
}

async function parsePaper(admin: any, student: string, paperId: number | string) {
  let pages = 0;
  for (let i = 0; i < 40; i++) {
    const { data: next } = await admin.rpc("next_parse_page", { p_paper: paperId });
    const page = (next as any)?.page ?? (next as any)?.page_no ?? null;
    if (!page) break;
    const res = await callFn("parse-page", { paper_id: paperId, page }, student);
    if (res?.error) throw new Error(String(res.error));
    pages++;
  }
  return { pages };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "content-type": "application/json" } });
}
