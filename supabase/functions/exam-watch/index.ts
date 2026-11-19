// exam-watch — look for anything that changed about these exams, not just dates.
//
// Watches: dates, paper format, sections and their timings, the topic list, and news.
// Every finding must carry the provider's own page. If it cannot, it is thrown away.
//
// Email: sent through Resend when RESEND_API_KEY is set (and ALERT_FROM is a verified sender).
// Without that key, findings are still logged and shown in the app banner, and marked un-emailed
// so nothing is lost — the parent can see them and we can send them once the key exists.
//
// Secrets: SARVAM_API_KEY (set), RESEND_API_KEY (optional), ALERT_FROM (optional)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";
const MODEL = "sarvam-m";

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "content-type": "application/json" } });

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

type Finding = { exam: string; kind: string; summary: string; detail?: string; source: string; sits_on?: string | null };
const KINDS = new Set(["date", "format", "timing", "topics", "news"]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    return await handle(req);
  } catch (e) {
    return json({ error: "the watch failed", detail: String((e as Error)?.message ?? e) });
  }
});

async function handle(req: Request) {

  const auth = req.headers.get("authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return json({ error: "not signed in" }, 401);

  const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // who is asking: verified with the service client, so no second client and no missing key
  const token = auth.replace(/^Bearer\s+/i, "");
  const { data: who, error: whoErr } = await supa.auth.getUser(token);
  const user = who?.user;
  if (whoErr || !user) return json({ error: "not signed in" }, 401);

  // a test email, so the parent can prove delivery without waiting for news
  let mode = "check";
  try { mode = (await req.json())?.mode ?? "check"; } catch (_) {}

  // whose calendar: this account, or the child this account looks after
  const { data: ownProfile } = await supa.from("profiles").select("student_id").eq("student_id", user.id).maybeSingle();
  let student = user.id;
  if (!ownProfile) {
    const { data: g } = await supa.from("guardians").select("student_id").eq("parent_id", user.id).limit(1).maybeSingle();
    if (g?.student_id) student = g.student_id;
  }

  const { data: cal } = await supa
    .from("exam_calendar").select("id, exam, sits_on, date_status").eq("student_id", student);
  const { data: sources } = await supa.from("date_sources").select("exam, url, note");
  const { data: recipients } = await supa.from("alert_recipients").select("email");

  const exams = (cal ?? []) as Array<{ id: string; exam: string; sits_on: string | null }>;

  if (mode === "test") {
    const key0 = Deno.env.get("RESEND_API_KEY");
    const from0 = Deno.env.get("ALERT_FROM");
    const to0 = (recipients ?? []).map((r) => r.email).filter(Boolean);
    if (!key0 || !from0) return json({ sent: false, reason: "no mail key or sender set", to: to0 });
    if (!to0.length) return json({ sent: false, reason: "no addresses", to: [] });

    const results = [];
    for (const addr of to0) {
      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${key0}` },
        body: JSON.stringify({
          from: from0, to: [addr],
          subject: "Quest Coach — test email",
          html: "<p>This is a test from Quest Coach. Exam updates for Atharv will arrive at this address.</p>",
        }),
      });
      const detail = r.ok ? null : (await r.text()).slice(0, 220);
      results.push({ to: addr, ok: r.ok, status: r.status, detail });
    }
    const anyOk = results.some((x) => x.ok);
    return json({
      sent: anyOk, results,
      to: results.filter((x) => x.ok).map((x) => x.to),
      failed: results.filter((x) => !x.ok).map((x) => ({ to: x.to, detail: x.detail })),
    });
  }

  if (!exams.length) return json({ checked: 0, alerts: [] });

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
      const body = await r.json();
      const raw = (body?.choices?.[0]?.message?.content ?? "").trim();
      const m = raw.match(/\{[\s\S]*\}/);
      if (m) findings = (JSON.parse(m[0]).findings ?? []) as Finding[];
    }
  } catch (_) { /* a failed check reports nothing */ }

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
  const key = Deno.env.get("RESEND_API_KEY");
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
      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${key}` },
        body: JSON.stringify({ from, to: [addr], subject: `Exam update — ${alerts.length} change${alerts.length === 1 ? "" : "s"}`, html }),
      });
      if (r.ok) anyOk = true;
    }
    if (anyOk) {
      emailed = alerts.length;
      await supa.from("alerts").update({ emailed_at: new Date().toISOString() })
        .in("id", alerts.map((a) => a.id));
    }
  }

  return json({ checked: exams.length, alerts, emailed, willEmailTo: to });
}
