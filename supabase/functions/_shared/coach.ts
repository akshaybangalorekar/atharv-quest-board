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

/** the envelope: named sections, in a fixed order, every one present even when empty */
export function buildEnvelope(c: any, opts: { parent: boolean; note?: string }): Envelope {
  const n = countsOf(c);

  const sections: Section[] = [
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
  if (c.library > 0 && says(/\b(read nothing|no sources|nothing from the web|cannot see any source)\b/i))
    clashes.push(`the LIBRARY line shows ${c.library} documents and ${c.sources} web sources`);
  if (c.questions > 0 && says(/\b(no questions|nothing stored|empty bank)\b/i))
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
