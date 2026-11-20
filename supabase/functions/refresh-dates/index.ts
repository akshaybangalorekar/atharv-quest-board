// refresh-dates — look at the providers' own pages for exam dates and log any change.
//
// What this can and cannot do, plainly:
//   The model has no browser. It is given the official page for each exam and asked for the date only when it is
//   sure. Every date it returns must carry the official URL it came from, and that URL's host must match the
//   provider we hold for that exam — otherwise the answer is thrown away. A change is applied and logged, and the
//   parent is told to confirm it with the school, because a school can move its own sitting.
//
// Secret: SARVAM_API_KEY (already set)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";
const MODEL = "glm5.3-flash";

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "content-type": "application/json" } });

type Row = { exam: string; sits_on: string | null; date_status: string | null };

const OFFICIAL: Record<string, string[]> = {
  aas: ["academicassessment.com.au"],
  edutest: ["edutest.com.au"],
  elms: ["edutest.com.au"],
  apsmo: ["apsmo.edu.au", "apsmo.com.au"],
  amc: ["amt.edu.au"],
  icas: ["icasassessments.com"],
};

function hostAllowed(exam: string, url: string): boolean {
  const e = exam.toLowerCase();
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

function isoDate(s: unknown): string | null {
  if (typeof s !== "string") return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const d = new Date(s + "T00:00:00Z");
  if (isNaN(d.getTime())) return null;
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  if (d < today) return null;                 // a past date is not a date to plan around
  if (d > new Date(Date.now() + 1000 * 60 * 60 * 24 * 900)) return null;
  return s;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const auth = req.headers.get("authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return json({ error: "not signed in" }, 401);

  const supa = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // who is asking, and whose calendar is it
  const asUser = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { authorization: auth } },
  });
  const { data: { user } } = await asUser.auth.getUser();
  if (!user) return json({ error: "not signed in" }, 401);

  const { data: kidId } = await asUser.rpc("viewing_student");
  const student = (kidId as string) ?? user.id;

  const { data: rows } = await supa
    .from("exam_calendar")
    .select("id, exam, sits_on, date_status")
    .eq("student_id", student);

  const { data: sources } = await supa.from("date_sources").select("exam, url");

  const list = (rows ?? []) as Row[];
  if (!list.length) return json({ checked: 0, changes: [] });

  const brief = list.map((r) => {
    const src = (sources ?? []).find((s) => s.exam === r.exam)?.url ?? "";
    return `${r.exam} — we have ${r.sits_on ?? "no date"} — official page: ${src}`;
  }).join("\n");

  const prompt = `You are checking exam dates for a Year 6 student in Melbourne.

For each exam below, say whether you are CERTAIN of the date the provider has published for the 2027 sitting.
Rules, strictly:
- Only answer with a date you are sure of. If you are not sure, leave "sits_on" null. Never guess.
- Give the official page the date came from in "source". It must be the provider's own site.
- Today is ${new Date().toISOString().slice(0, 10)}.
- Dates are ISO yyyy-mm-dd.

Exams:
${brief}

Reply with JSON only:
{"dates":[{"exam":"...","sits_on":"2027-02-06" or null,"source":"https://..."}]}`;

  let dates: Array<{ exam: string; sits_on: string | null; source: string }> = [];
  try {
    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: { "content-type": "application/json", "api-subscription-key": Deno.env.get("SARVAM_API_KEY")! },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.1,
        messages: [
          { role: "system", content: "You answer with JSON only, and you never invent a date." },
          { role: "user", content: prompt },
        ],
      }),
    });
    if (r.ok) {
      const body = await r.json();
      const raw = (body?.choices?.[0]?.message?.content ?? "").trim();
      const m = raw.match(/\{[\s\S]*\}/);
      if (m) dates = JSON.parse(m[0]).dates ?? [];
    }
  } catch (e) { console.error("refresh-dates check failed:", String((e as Error)?.message ?? e)); }

  const changes: Array<Record<string, unknown>> = [];

  for (const d of dates) {
    const row = list.find((r) => r.exam === d.exam);
    if (!row) continue;
    const when = isoDate(d.sits_on);
    if (!when) continue;                                  // nothing said, or not a usable date
    if (!hostAllowed(row.exam, String(d.source ?? ""))) continue;   // no official page, no change
    if (row.sits_on === when) continue;                   // nothing to do

    await supa.from("exam_calendar").update({ sits_on: when, date_status: "checked" }).eq("id", (row as any).id);
    changes.push({ exam: row.exam, from: row.sits_on, to: when, source: d.source });
  }

  await supa.from("date_checks").insert({
    student_id: student,
    changes,
    seen: changes.length === 0,     // only an actual change needs a banner
  });

  return json({ checked: list.length, changes });
});
