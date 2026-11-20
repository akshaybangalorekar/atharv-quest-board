// _shared/generate.ts — turn what she has read into questions, without being asked.
//
// The rule this implements: reading the sources fills the bank. Pressing Generate is for
// "use my uploads / my material for twenty more", not for the very first fill.
//
// Every question still has to pass the §2A gate before it is stored: it is read on its own,
// solved, and discarded if it is ambiguous, unanchored or self-contradictory.

import { ask, jsonIn } from "./mod.ts";
import { checkQuestion, verdictColumns } from "./quality.ts";

const SUBJECT_RULES: Record<string, string> = {
  maths: "Year 6 arithmetic only. Clean numbers. One definite answer.",
  reasoning: `A REASONING question, not arithmetic: verbal (analogies, odd-one-out, word relationships, codes),
numerical (series, matrices), figural (rotation, reflection, next in sequence), spatial (nets, plans, views).
One short answer: a word, a letter or a number.`,
  reading: `A READING question: a 60-110 word passage at Year 6 level, then one question about it — main idea,
detail, inference, vocabulary in context or author's purpose. Four options, exactly one correct.`,
  writing: `A WRITTEN EXPRESSION prompt, not multiple choice: one persuasive or narrative task under 30 words,
saying the form and roughly the length. The answer is what a good response must contain.`,
};

const WRITE = (topic: string, subject: string, material: string, n: number) => `You write practice questions for
an 11-year-old in Melbourne preparing for Australian competitions and scholarship tests.

Topic: ${topic}.
${SUBJECT_RULES[subject] ?? ""}

THE QUESTION MUST BE ANSWERABLE FROM ITS OWN WORDS. Every quantity anchored to a named thing. Never say
"the picture", "the table" or "shown below" unless you also give "fig". If two answers are possible it is wrong.

${material ? `Here is material from the sources she has read. Follow its content and style; never copy it word for word:\n${material}\n` : ""}
Write ${n} questions. Reply with JSON only:
{"rows":[{"q":"the question","a":"the answer","m":"one line of method","d":1,
          "options":["a","b","c","d"]}]}
Options are optional; when given there must be exactly one correct, equal to "a".`;

/** fill the thinnest strand of each exam from what she has read */
export async function fillFromMaterial(admin: any, opts: { perStrand?: number; maxStrands?: number } = {}) {
  const perStrand = opts.perStrand ?? 3;
  const maxStrands = opts.maxStrands ?? 6;

  const { data: chapters } = await admin
    .from("chapters").select("n, title, source, subject, practice")
    .order("practice", { ascending: true }).limit(60);

  const picked: any[] = [];
  const seen = new Set<string>();
  for (const ch of chapters ?? []) {
    const key = String(ch.source ?? "").toLowerCase();
    if (seen.has(key)) continue;             // one strand per exam per run, so it spreads
    seen.add(key);
    picked.push(ch);
    if (picked.length >= maxStrands) break;
  }

  const made: Array<{ chapter: number; idx: number; ok: boolean }> = [];

  for (const ch of picked) {
    const { data: passages } = await admin.rpc("search_docs", {
      p_query: ch.title ?? "mathematics", p_chapter: null, p_limit: 2,
    });
    const material = (passages ?? []).map((x: any) => String(x.body ?? "").slice(0, 400)).join("\n\n");

    const raw = await ask(WRITE(String(ch.title), ch.subject ?? "maths", material, perStrand), "Write them now.", 0.8, 1400);
    const parsed = jsonIn(raw);
    const rows = (parsed?.rows ?? []).filter((r: any) => r?.q && r?.a).slice(0, perStrand);

    const { data: maxRow } = await admin.from("problems")
      .select("idx").eq("chapter", ch.n).order("idx", { ascending: false }).limit(1).maybeSingle();
    let idx = maxRow?.idx ?? 0;

    for (const row of rows) {
      const q = String(row.q).trim();

      // the gate: it must be answerable on its own
      const verdict = await checkQuestion(q, false);
      if (!verdict.ok) continue;

      const { data: dup } = await admin.from("problems").select("idx").eq("chapter", ch.n).eq("prompt", q).maybeSingle();
      if (dup) continue;

      idx += 1;
      const { error } = await admin.from("problems").insert({
        chapter: ch.n, idx, prompt: q,
        ...(Array.isArray(row.options) && row.options.length >= 3 ? { options: row.options } : {}),
        difficulty: Number(row.d) || 2,
        technique_tags: [String(ch.title).split("·").pop()?.trim() ?? String(ch.title)],
        source: ch.source ?? "book",
        ...verdictColumns(verdict),
      });
      if (error) { idx -= 1; continue; }

      await admin.from("problem_answers").insert({
        chapter: ch.n, idx, answer: `${row.a} — ${row.m ?? ""}`.trim(),
        method: String(row.m ?? "").slice(0, 500), answer_key: String(row.a).trim(),
        mark_mode: "auto", solved_by: "llm", verified: true,
      });
      made.push({ chapter: ch.n, idx, ok: true });
    }
  }

  return { strands: picked.length, made: made.length, rows: made };
}
