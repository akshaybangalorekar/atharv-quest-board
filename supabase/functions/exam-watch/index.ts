// exam-watch — anything that changed about these exams: dates, format, timing, topics, news.
// Plumbing comes from _shared/mod.ts.

import { serve, ok, fail, context, studentFor } from "./_shared/mod.ts";

const OFFICIAL: Record<string, string[]> = {
  aas: ["academicassessment.com.au"],
  edutest: ["edutest.com.au"],
  elms: ["edutest.com.au"],
  apsmo: ["apsmo.edu.au", "apsmo.com.au"],
  amc: ["amt.edu.au"],
  icas: ["icasassessments.com"],
};

function hostAllowed(exam: string, url: string): boolean {
  const e = String(exam ?? "").toLowerCase();
  const key = e.includes("aas") ? "aas"
    : e.includes("elms") ? "elms"
    : e.includes("edutest") ? "edutest"
    : e.includes("apsmo") || e.includes("olympiad") ? "apsmo"
    : e.includes("amc") ? "amc"
    : e.includes("icas") ? "icas" : "";
  if (!key) return false;
  try {
    const host = new URL(url).host.replace(/^www\./, "");
    return OFFICIAL[key].some((d) => host === d || host.endsWith("." + d));
  } catch { return false; }
}


/* one message to one address, through whichever provider has a key.
   Brevo accepts a verified single sender, so it can write to anyone without owning a domain. */
async function sendOne(to: string, from: string, subject: string, html: string) {
  const brevo = Deno.env.get("BREVO_API_KEY");
  const resend = Deno.env.get("RESEND_API_KEY");

  if (brevo) {
    const senderEmail = (from.match(/<([^>]+)>/)?.[1] ?? from).trim();
    const senderName = (from.match(/^([^<]+)</)?.[1] ?? "Quest Coach").trim();
    const r = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "content-type": "application/json", "api-key": brevo },
      body: JSON.stringify({
        sender: { email: senderEmail, name: senderName },
        to: [{ email: to }],
        subject, htmlContent: html,
      }),
    });
    return { ok: r.ok, status: r.status, detail: r.ok ? null : (await r.text()).slice(0, 220) };
  }

  if (resend) {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${resend}` },
      body: JSON.stringify({ from, to: [to], subject, html }),
    });
    return { ok: r.ok, status: r.status, detail: r.ok ? null : (await r.text()).slice(0, 220) };
  }

  return { ok: false, status: 0, detail: "no mail key set" };
}

type Finding = { exam: string; kind: string; summary: string; detail?: string; source: string; sits_on?: string | null };
const KINDS = new Set(["date", "format", "timing", "topics", "news"]);

serve(handle);

async function handle(req: Request) {

  const ctx = await context(req);
  if ("error" in ctx) return ctx.error;
  const { admin: supa, user } = ctx;

  // a test email, so the parent can prove delivery without waiting for news
  let mode = "check";
  try { mode = (await req.json())?.mode ?? "check"; } catch (e) { console.error("exam-watch step failed:", String((e as Error)?.message ?? e)); }

  // whose calendar: this account, or the child this account looks after
  const student = await studentFor(supa, user.id);

  const { data: cal } = await supa
    .from("exam_calendar").select("id, exam, sits_on, date_status").eq("student_id", student);
  const { data: sources } = await supa.from("date_sources").select("exam, url, note");
  const { data: recipients } = await supa.from("alert_recipients").select("email");

  const exams = (cal ?? []) as Array<{ id: string; exam: string; sits_on: string | null }>;

  if (mode === "test") {
    const key0 = Deno.env.get("BREVO_API_KEY") ?? Deno.env.get("RESEND_API_KEY");
    const from0 = Deno.env.get("ALERT_FROM");
    const to0 = (recipients ?? []).map((r) => r.email).filter(Boolean);
    if (!key0 || !from0) return ok({ sent: false, reason: "no mail key or sender set", to: to0 });
    if (!to0.length) return ok({ sent: false, reason: "no addresses", to: [] });

    const results = [];
    for (const addr of to0) {
      const r = await sendOne(addr, from0, "Quest Coach — test email",
        "<p>This is a test from Quest Coach. Exam updates for Atharv will arrive at this address.</p>");
      results.push({ to: addr, ok: r.ok, status: r.status, detail: r.detail });
    }
    const anyOk = results.some((x) => x.ok);
    return ok({
      sent: anyOk, results,
      to: results.filter((x) => x.ok).map((x) => x.to),
      failed: results.filter((x) => !x.ok).map((x) => ({ to: x.to, detail: x.detail })),
    });
  }

  if (!exams.length) return ok({ checked: 0, alerts: [] });

  const brief = exams.map((r) => {
    const s = (sources ?? []).find((x) => x.exam === r.exam);
    return `- ${r.exam}: we have the date ${r.sits_on ?? "unset"}; official page ${s?.url ?? "unknown"}`;
  }).join("\n");

  const prompt = `You are keeping a parent informed about exams a Year 6 student in Melbourne will sit in 2027.

Report ONLY things you are certain of, and ONLY where you can give the provider's own page as the source.
Anything you are unsure of, leave out. Never guess a date, a section, a duration or a topic.

Look for all of these:
- a changed or newly published exam DATE
- a change in PAPER FORMAT (number of papers, sections, question types)
- a change in TIMING (how long a paper or section runs)
- a change in the TOPIC LIST or curriculum content
- notable NEWS about the exam

Today is ${new Date().toISOString().slice(0, 10)}.

Exams:
${brief}

Reply with JSON only:
{"findings":[{"exam":"...","kind":"date|format|timing|topics|news","summary":"one short sentence","detail":"optional","source":"https://...","sits_on":"2027-02-06" or null}]}
If nothing has changed, reply {"findings":[]}.`;

  let findings: Finding[] = [];
  try {
    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: { "content-type": "application/json", "api-subscription-key": Deno.env.get("SARVAM_API_KEY")! },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.1,
        messages: [
          { role: "system", content: "You answer with JSON only. You never invent a fact or a source." },
          { role: "user", content: prompt },
        ],
      }),
    });
    if (r.ok) {
      const body = await r.ok();
      const raw = (body?.choices?.[0]?.message?.content ?? "").trim();
      const m = raw.match(/\{[\s\S]*\}/);
      if (m) findings = (JSON.parse(m[0]).findings ?? []) as Finding[];
    }
  } catch (e) { console.error("exam-watch check failed:", String((e as Error)?.message ?? e)); }

  const kept: Finding[] = [];
  for (const f of findings) {
    if (!KINDS.has(String(f.kind))) continue;
    if (!f.summary || String(f.summary).length < 8) continue;
    if (!hostAllowed(f.exam, String(f.source ?? ""))) continue;   // no official page, no alert
    kept.push(f);
  }

  const alerts: Array<Record<string, unknown>> = [];

  for (const f of kept) {
    const row = exams.find((r) => r.exam === f.exam);
    if (!row) continue;

    // a date finding also moves the timetable
    if (f.kind === "date" && f.sits_on && /^\d{4}-\d{2}-\d{2}$/.test(f.sits_on) && f.sits_on !== row.sits_on) {
      await supa.from("exam_calendar").update({ sits_on: f.sits_on, date_status: "checked" }).eq("id", row.id);
    }

    const { data: ins } = await supa.from("alerts").insert({
      student_id: student, kind: f.kind, exam: f.exam,
      summary: f.summary, detail: f.detail ?? null, source: f.source,
    }).select("id, kind, exam, summary, detail, source").single();

    if (ins) alerts.push(ins);
  }

  // ---- the email, if we are allowed to send one ----
  const key = Deno.env.get("BREVO_API_KEY") ?? Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("ALERT_FROM");
  const to = (recipients ?? []).map((r) => r.email).filter(Boolean);
  let emailed = 0;

  if (key && from && to.length && alerts.length) {
    const lines = alerts.map((a) =>
      `- [${a.kind}] ${a.exam}: ${a.summary}${a.detail ? `\n  ${a.detail}` : ""}\n  ${a.source}`).join("\n\n");
    const html = `<h2>Quest Coach — exam update</h2>
      <p>${alerts.length} change${alerts.length === 1 ? "" : "s"} found for Atharv's exams. Each one is from the provider's own page.</p>
      <pre style="font:14px/1.6 system-ui;white-space:pre-wrap">${lines.replace(/</g, "&lt;")}</pre>
      <p style="color:#666">Confirm anything that matters with the school before you plan around it.</p>`;

    let anyOk = false;
    for (const addr of to) {
      const r = await sendOne(addr, from, `Exam update — ${alerts.length} change${alerts.length === 1 ? "" : "s"}`, html);
      if (r.ok) anyOk = true;
    }
    if (anyOk) {
      emailed = alerts.length;
      await supa.from("alerts").update({ emailed_at: new Date().toISOString() })
        .in("id", alerts.map((a) => a.id));
    }
  }

  return ok({ checked: exams.length, alerts, emailed, willEmailTo: to });
}
