// _shared/authority.ts — Top Scope is the final word for Edutest and AAS.
//
// When a parent ticks TOPSCOPE_EDUTEST or TOPSCOPE_AAS and uploads a file, that file outranks
// everything: what she read on the internet, what she wrote herself, what Generate produced.
// This module reviews every existing question for that exam against the Top Scope material and
// corrects the ones that do not match.

import { ask, jsonIn } from "./mod.ts";

const REVIEW = (material: string) => `You are checking whether a practice question matches the material a
tutoring college gave this child. The college material is the final authority — it outranks anything else.

Here is the college's material:
${material}

You will be shown one question. Decide:
- "matches": YES if the question is the right kind, level and scope for this material. NO otherwise.
- "fixed": if NO, rewrite the question so it does match — same skill, but the style, level and wording the
  material uses. Keep it answerable from its own words: every quantity anchored to a named thing, one answer.
- "why": one short sentence.

Reply with JSON only: {"matches":"YES","fixed":"","why":""}`;

/** review one exam's questions against its authority material */
export async function alignExam(admin: any, exam: string, opts: { limit?: number } = {}) {
  const limit = opts.limit ?? 20;

  const { data: material } = await admin.rpc("authority_material", { p_exam: exam, p_limit: 6 });
  const passages = (material ?? []).map((x: any) => String(x.body ?? "")).join("\n\n").slice(0, 3500);
  if (!passages) return { exam, reviewed: 0, changed: 0, note: "no Top Scope material for this exam yet" };

  const { data: rows } = await admin.rpc("exam_questions", { p_exam: exam });
  const live = (rows ?? []).filter((r: any) => !r.authority).slice(0, limit);

  let changed = 0;
  const system = REVIEW(passages);

  for (const r of live) {
    const verdict = jsonIn(await ask(system, `Question: ${r.prompt}`, 0.2, 700));
    if (!verdict) continue;

    if (String(verdict.matches).toUpperCase() === "YES") continue;

    const fixed = String(verdict.fixed ?? "").trim();
    if (!fixed) continue;

    // the corrected wording replaces the old one, and it goes back to draft until the gate passes it again
    const { error } = await admin.from("problems").update({ prompt: fixed }).eq("chapter", r.chapter).eq("idx", r.idx);
    if (error) continue;

    await admin.rpc("set_question_status", {
      p_chapter: r.chapter, p_idx: r.idx, p_status: "draft",
      p_note: `corrected to match official material: ${String(verdict.why ?? "").slice(0, 120)}`,
    });
    changed++;
  }

  return { exam, reviewed: live.length, changed };
}
