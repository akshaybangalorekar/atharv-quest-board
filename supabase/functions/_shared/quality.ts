// _shared/quality.ts — one place for the rule that decides whether a question may be shown.
//
// It used to live in three functions (make-questions, parse-page, train-coach) and would have
// drifted. Now every writer imports this and calls the same two functions.

import { ask, jsonIn } from "./mod.ts";

export const SOLVE = `You check whether a question can be answered at all, before it is given to a child.

Read it on its own, with no extra information. Then answer:
- "solvable": YES only if it states everything needed and leads to exactly one answer. NO if a quantity is
  mentioned without saying which object it belongs to, if a drawing or table is referred to but not shown,
  if two answers are possible, or if the numbers contradict each other.
- "why": one short sentence naming the gap. Empty when YES.

Be strict. A question that cannot be answered is worse than no question.
Reply with JSON only: {"solvable":"YES","why":""}`;

const FIG_WORD = /\b(picture|diagram|figure|table|chart|graph|drawing|image|shown|below)\b/i;

export type Verdict = { ok: boolean; why: string };

/** may this question be shown? text alone decides, unless it carries its own figure */
export async function checkQuestion(text: string, hasFigure: boolean): Promise<Verdict> {
  const q = String(text ?? "").trim();
  if (!q) return { ok: false, why: "empty question" };

  // it points at a drawing, and no drawing came with it
  if (FIG_WORD.test(q) && !hasFigure) return { ok: false, why: "it refers to a drawing that is not there" };

  try {
    const v = jsonIn(await ask(SOLVE, `Question: ${q}`));
    if (!v) return { ok: false, why: "it could not be checked" };
    const ok = String(v.solvable).toUpperCase() === "YES";
    return { ok, why: ok ? "" : String(v.why ?? "it cannot be answered as written") };
  } catch (_) {
    return { ok: false, why: "it could not be checked" };
  }
}

/** check a batch, and report what was kept and what was held back */
export async function checkBatch(rows: Array<{ q: string; hasFigure?: boolean }>) {
  const results: Verdict[] = [];
  for (const r of rows) results.push(await checkQuestion(r.q, !!r.hasFigure));
  return {
    results,
    kept: results.filter((r) => r.ok).length,
    held: results.filter((r) => !r.ok).length,
  };
}

/** the one status a question can carry, and the note that explains it */
export function verdictColumns(v: Verdict, clearedAgainstOfficial = false) {
  const status = !v.ok ? "failed" : clearedAgainstOfficial ? "cleared" : "provisional";
  return { status, status_note: v.ok ? null : v.why, status_at: new Date().toISOString() };
}

/** the same transition, made through the one function that owns it */
export async function setStatus(admin: any, chapter: number, idx: number, status: string, note?: string) {
  await admin.rpc("set_question_status", { p_chapter: chapter, p_idx: idx, p_status: status, p_note: note ?? null });
}
