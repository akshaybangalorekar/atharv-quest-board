// _shared/coach.ts — the context envelope, and the guard that checks her reply against it.
//
// Why this exists: twice she was handed live data and still answered "nothing". The facts were a
// long string with the important lines buried, and nothing checked her reply against them. Now the
// context has named sections, every section is required, and her answer is compared with the
// envelope before it is sent.

export type Section = { key: string; title: string; body: string; count?: number };

export type Envelope = {
  sections: Section[];
  text: string;
  counts: { library: number; bank: number; questions: number; uploads: number; attempts: number; sources: number };
};

/** read the numbers out of a coach_context payload */
function countsOf(c: any) {
  const lib = String(c?.library ?? "");
  const bank = String(c?.bank ?? "");
  const num = (s: string, re: RegExp) => {
    const m = s.match(re);
    return m ? Number(m[1]) : 0;
  };
  return {
    library: num(lib, /(\d+)\s+documents/),
    sources: num(lib, /From the web:\s*(\d+)/),
    bank: num(bank, /across\s+(\d+)\s+strands/),
    questions: num(bank, /(\d+)\s+questions stored/),
    uploads: Number(c?.uploads?.papers ?? 0),
    attempts: Number(c?.truth?.attempts?.total ?? 0),
  };
}

/** how many passages she is holding, read from the library line when the context has no count */
function passagesOf(c: any) {
  const m = String(c?.library ?? "").match(/(\d+)\s+passages?/);
  return m ? Number(m[1]) : (Array.isArray(c?.material) ? c.material.length : 0);
}

/** the envelope: named sections, in a fixed order, every one present even when empty */
export function buildEnvelope(c: any, opts: { parent: boolean; note?: string }): Envelope {
  const n = countsOf(c);

  const sections: Section[] = [
    {
      key: "headline",
      title: "THE SHORT ANSWER, IF YOU ARE ASKED WHAT YOU HAVE",
      body: `You have read ${n.library} documents (${n.sources} from the web) holding ${passagesOf(c)} passages, ` +
            `and ${n.questions} question${n.questions === 1 ? "" : "s"} are stored in the bank` +
            `${n.uploads ? `, plus ${n.uploads} file${n.uploads === 1 ? "" : "s"} a parent uploaded` : ""}. ` +
            `Say these numbers when you are asked. Never say "nothing" while any of them is above zero.`,
    },
    {
      key: "live",
      title: "WHEN THIS WAS READ",
      body: `Computed from the database at this moment (${c?.today ?? "today"}) for this message. No cache, no other source.`,
    },
    {
      key: "library",
      title: "WHAT SHE HAS READ (LIBRARY)",
      body: String(c?.library ?? "LIBRARY: nothing read yet."),
      count: n.library,
    },
    {
      key: "bank",
      title: "WHAT IS STORED (QUESTION BANK)",
      body: String(c?.bank ?? "QUESTION BANK: empty."),
      count: n.questions,
    },
    {
      key: "uploads",
      title: "WHAT THE PARENT HAS UPLOADED",
      body: JSON.stringify(c?.uploads ?? {}),
      count: n.uploads,
    },
    {
      key: "child",
      title: "THE CHILD'S OWN RECORD",
      body: JSON.stringify({
        name: c?.truth?.student?.name ?? c?.name ?? null,
        attempts_total: c?.truth?.attempts?.total ?? 0,
        attempts_7d: c?.truth?.attempts?.last_7 ?? 0,
        accuracy_7d: c?.truth?.attempts?.accuracy_7 ?? 0,
        sessions_7d: c?.truth?.sessions?.last_7 ?? 0,
        xp: c?.truth?.student?.xp ?? 0,
        streak: c?.truth?.student?.streak ?? 0,
      }),
    },
    {
      key: "exams",
      title: "THE EXAMS AND THEIR DATES",
      body: (c?.truth?.families ?? []).map((f: any) =>
        `${f.label}: ${f.exam_on ?? "no date"}, ${f.topics_all ?? 0} topics, ${f.items ?? 0} questions`).join("\n") || "none",
    },
    {
      key: "material",
      title: "PASSAGES SHE MAY QUOTE",
      body: JSON.stringify(c?.material ?? []),
      count: Array.isArray(c?.material) ? c.material.length : 0,
    },
    {
      key: "open_paper",
      title: "A PAPER STARTED AND NOT FINISHED",
      body: (c?.open_paper && (c.open_paper.items ?? []).length)
        ? `${c.open_paper.kind}, ${c.open_paper.items.length} questions, started ${c.open_paper.started_at}`
        : "none",
    },
    {
      key: "history",
      title: opts.parent ? "YOUR EARLIER CONVERSATION WITH THE PARENT" : "YOUR EARLIER CONVERSATION WITH HIM",
      body: JSON.stringify((opts.parent ? c?.recent_parent_chat : c?.recent_chat) ?? []).slice(0, 1200),
    },
    {
      key: "readiness",
      title: "READY FOR TOOLS?",
      body: toolReadiness(n).line,
    },
  ];

  const missing = sections.filter((s) => !s.body || !s.body.trim()).map((s) => s.key);
  if (missing.length) {
    // a section with nothing in it is a bug in the context, not an empty database
    sections.push({ key: "context_error", title: "CONTEXT INCOMPLETE", body: `missing: ${missing.join(", ")}` });
  }

  const text = sections.map((s) => `[${s.title}]\n${s.body}`).join("\n\n");
  return { sections, text, counts: n };
}

/** when she has enough to work with for tool-calling to be worth it */
export function toolReadiness(n: Envelope["counts"]) {
  const missing: string[] = [];
  if (n.questions < 30) missing.push(`${30 - n.questions} more questions in the bank`);
  if (n.attempts < 10) missing.push(`${10 - n.attempts} more attempts from him`);
  if (n.sources < 3) missing.push(`${3 - n.sources} more sources read`);
  return {
    ready: missing.length === 0,
    missing,
    line: missing.length
      ? `Not yet — she is short of: ${missing.join("; ")}. She must not offer tool use until these are met.`
      : "Yes — enough questions, attempts and sources. If a parent asks about her abilities, say she is ready for tools.",
  };
}

const DENIAL = /(nothing|no data|not in the log|nothing has reached me|cannot see|empty|no sources|no questions|zero)/i;

/** does the reply claim emptiness about something the envelope shows as non-empty? */
export function checkReply(reply: string, env: Envelope) {
  const text = String(reply ?? "");
  if (!DENIAL.test(text)) return { ok: true, reason: "" };

  const c = env.counts;
  const says = (re: RegExp) => re.test(text);

  const clashes: string[] = [];
  const deniedReading = /\b(read nothing|no sources|nothing from the web|cannot see any source|nothing has come through|nothing has been (uploaded|read|logged)|no reading logged|not read anything|nothing from any online source)\b/i;
  const deniedBank = /\b(bank is empty|question bank is empty|no questions|nothing stored|empty bank|no question pool)\b/i;
  const deniedExams = /\b(no exams registered|no exams|no strands|no exam set)\b/i;

  if (c.library > 0 && says(deniedReading))
    clashes.push(`the LIBRARY line shows ${c.library} documents and ${c.sources} web sources`);
  if (c.bank > 0 && says(deniedExams))
    clashes.push(`the QUESTION BANK line names ${c.bank} strands across the exams`);
  if (c.questions > 0 && says(deniedBank))
    clashes.push(`the QUESTION BANK line shows ${c.questions} questions`);
  if (c.uploads > 0 && says(/\b(nothing uploaded|no uploads|no files)\b/i))
    clashes.push(`the UPLOADS line shows ${c.uploads} papers`);
  if (c.attempts > 0 && says(/\b(no attempts|nothing attempted|no sessions)\b/i))
    clashes.push(`his record shows ${c.attempts} attempts`);

  if (!clashes.length) return { ok: true, reason: "" };
  return {
    ok: false,
    reason: clashes.join("; "),
    correction:
      `Your reply contradicts the context you were given: ${clashes.join("; ")}. ` +
      `Rewrite it using those exact figures, and never say nothing when a line shows a number above zero.`,
  };
}

/* the rules that changed this week, kept in one place and read out at every start */
export const NEW_RULES = `§12 HOW A DAY STARTS, AND WHAT IS HARD.
§12.1 A session opens with a short exchange, one question per message: how his studies are going; what he is doing in
Top Scope; what he is doing in school maths; what he is doing with his private tutor and in IXL. Wait for each answer.
§12.2 Then align: name the chapter or topic the answers point to, say why in one line, and only then start. If he says
"just start", start. Never repeat a question he has already answered.
§12.3 When he or a parent says a kind of question is hard: say it back; ask which exam if it is not obvious; teach the
trick with one worked example; write questions of that kind into that exam; put that kind into the next mock. Not
finished until all four are done. Never file a difficulty against an exam nobody named.
§12.4 If he skips a chapter offer exactly two alternatives. After a second skip, stop offering: decide, say why, start.
§12.5 If questions are sitting ambiguous, tell a parent in your first or second line, after the child's status, and
offer to review them. Never hide them, never call them practice.
§13 WHAT A QUESTION IS, AND WHETHER IT CAN BE TRUSTED.
§13.1 Verified = agrees with official material for that exam. Not verified = answerable, unconfirmed. Held back =
contradicts the material or is off the syllabus. Use those three words and no others.
§13.2 Every question you show names its source and whether it is verified. A question that names a drawing and has none
is refused, never shown.
§13.3 Official material outranks the internet and your own questions, for that exam only. A question off that exam's
official topic list is held back as out of scope.
§13.4 Every claim carries its number. "7 of 10, up from 4" is allowed; "you have mastered it" is not.
§12.6 A question he raises out of turn — typed or in a photo — is never turned away and never lost. Answer it briefly,
then put it into his practice bank for the exam it belongs to: questions of that same kind, written to the official
topics for that exam, so he meets it again in practice. Say one line that you have kept it for him. If the exam is not
obvious, ask once, quietly, and keep the question until he answers.
§12.7 When he is finding things easy, say so with a number, then switch him to tough mode and name it from the epics:
"Vajra mode" for a run of hard questions (Indra's thunderbolt), "Gandiva" for accuracy under time (Arjuna's bow),
"Hanuman's leap" for a long streak, "Ekalavya's focus" for finishing without help, "Abhimanyu's chakravyuh" for a
question above his level that he stays with. Use one name at a time, never a list, and never for a wrong answer.
§13.5 Offer a mock only when all three hold: 30+ questions for that exam, 70%+ over the last 20 attempts, every topic
in scope attempted once. When you decline, say which of the three is short, with the numbers.`;
