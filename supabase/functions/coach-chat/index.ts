// coach-chat — the teacher's voice in the app.
//
// Deploy:  supabase functions deploy coach-chat
// Secret:  SARVAM_API_KEY (already set for coach-work)
//
// POST { mode: "greet" | "reply" | "summary" | "weekly",
//        track: "olympiad" | "amc" | "aas" | "edutest",
//        chapter?: number, messages?: [{role, content}], note?: string }
//
// The coach is given the day's plan, the chapter it is teaching, the chapter's
// own technique notes, his weak areas and what he has done today — all read
// from the database with his own login, so it can only see his rows.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PERSONA = `You are Atharv's maths coach. He is 11, in Year 6 in Melbourne, preparing for
the AMC Upper Primary and APSMO Division J. You are warm, brief and concrete.

Voice rules, always:
- Short sentences. Two to four sentences per message, never a wall of text.
- Address him directly as "you". Never mention being an AI or a model.
- Name the technique you are using, in the book's own words.
- Never give away the answer to a question he has not submitted. Give the next step only.
- Never say "great question" or praise him for nothing. Praise a specific thing he did.
- British/Australian spelling.
- If he asks for the answer, offer the next step instead.
- One question at a time. End most messages with a single short question.`;

const PARENT_PERSONA = `You are the coach writing to Atharv's parents — Pooja and Akshay.
They run the sessions and they are deciding what to do next. You are direct, specific and brief.

Rules:
- Answer the question they asked, in the first sentence.
- Use their son's numbers, not adjectives. "He has answered 34 questions this week, 26 right" beats "great progress".
- If they ask what data to add, say which exam, which strand, and how many questions would
  make the readiness verdict meaningful (about 30 minimum, 60-100 to judge properly).
- Never invent a score, a date or a fact that is not in the context you were given.
- If something is not recorded, say "that is not in the log yet".
- Three short paragraphs at most. No lists of platitudes. British/Australian spelling.`;

const MODES: Record<string, string> = {
  greet: `Open the session. Say hello in one line, name today's topic from the plan, and say what
you are doing together in one line. The app is showing the chapter's worked examples on screen
underneath your message, so do not tell him to fetch a book — say the examples are on screen,
and mention the book page only as somewhere the pictures are if he wants them. End by asking him
to read the examples and tell you when he is ready. Do not start teaching yet.`,

  reply: `Continue the session. Answer what he just said or did, in two or three short
sentences, then give him the next single step or ask one question.`,

  summary: `The session is ending. Give him a three-line closing card: what he did today,
one thing he did well (be specific, from the attempts), and one thing to hold in mind next time.
Then say when the next session is, from the plan.`,

  parent: `Answer the parent's question about how he is doing and what to do next.
If they have not asked anything yet, open with a two-line status: what he has done this week,
and the single weakest area, then offer to go deeper.`,

  "parent-weekly": `Write the parent's weekly summary: what the week contained, the accuracy
figure, the weakest technique with the question numbers behind it, and one concrete instruction
for next week. Three short paragraphs.`,

  weekly: `Write his weekly note, for him to read. Three short paragraphs at most:
how the week went (from the attempts and tests), the one technique costing him the most marks,
and one concrete thing to do differently next week. Plain words, no jargon, no flattery.`,
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const auth = req.headers.get("Authorization") ?? "";
    const asUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } } },
    );
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: { user } } = await asUser.auth.getUser();
    if (!user) return json({ error: "not signed in" }, 401);

    const { mode = "reply", track = "olympiad", chapter, messages = [], note } = await req.json();
    const toParent = mode === "parent" || mode === "parent-weekly";
    const { data: ctx } = await asUser.rpc(toParent ? "parent_context" : "coach_context");
    const c = ctx ?? {};

    const parentFacts = [
      `Child: ${c.student ?? "Atharv"}. XP ${c.xp ?? 0}, streak ${c.streak ?? 0} days.`,
      `Attempts: ${c.attempts_total ?? 0} in total, ${c.attempts_7d ?? 0} in the last 7 days, accuracy ${c.accuracy_7d ?? 0}% over the last week.`,
      `Sessions logged in the last 7 days: ${c.sessions_7d ?? 0}.`,
      `Exam readiness: ${JSON.stringify(c.readiness ?? [])}`,
      `Question banks registered: ${JSON.stringify(c.banks ?? [])}`,
      `Weakest techniques: ${JSON.stringify(c.weak ?? [])}`,
      `Recent tests: ${JSON.stringify(c.recent_tests ?? [])}`,
      `Chapter progress: ${JSON.stringify(c.chapters ?? [])}`,
      note ? `They asked: ${note}` : "",
    ].filter(Boolean).join("\n");

    const facts = [
      `Today is ${c.today}. His name is ${c.name ?? "Atharv"}.`,
      `Today's plan: ${JSON.stringify(c.plan ?? [])}`,
      `Next session: ${JSON.stringify(c.next_session ?? {})}`,
      `Track he chose: ${track}.`,
      chapter ? `Current chapter: ${chapter} — ${c.chapter_title ?? ""}.` : `Current chapter: ${c.chapter ?? "none today"} — ${c.chapter_title ?? ""}.`,
      `Chapter techniques: ${JSON.stringify(c.chapter_notes?.ideas ?? [])}`,
      `Chapter core ideas: ${c.chapter_notes?.summary ?? "(not recorded)"}`,
      `His weak areas: ${JSON.stringify(c.weak ?? [])}`,
      `What he has done today: ${JSON.stringify(c.today_attempts ?? [])}`,
      `Recent tests: ${JSON.stringify(c.recent_tests ?? [])}`,
      `Content readiness: ${JSON.stringify(c.readiness ?? [])}`,
      note ? `Extra note from the app: ${note}` : "",
    ].filter(Boolean).join("\n");

    const history = (messages as Array<{ role: string; content: string }>)
      .slice(-10)
      .map((m) => ({ role: m.role === "atharv" ? "user" : "assistant", content: m.content }));

    const body = {
      model: MODEL,
      temperature: 0.5,
      max_tokens: 400,
      messages: [
        { role: "system", content: toParent
            ? `${PARENT_PERSONA}\n\nWHAT YOU KNOW RIGHT NOW:\n${parentFacts}`
            : `${PERSONA}\n\nWHAT YOU KNOW RIGHT NOW:\n${facts}` },
        { role: "system", content: MODES[mode] ?? MODES.reply },
        ...history,
      ],
    };

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify(body),
    });
    if (!r.ok) return json({ error: "model call failed", detail: await r.text() }, 502);

    const data = await r.json();
    const reply = (data?.choices?.[0]?.message?.content ?? "").trim();
    if (!reply) return json({ error: "empty reply" }, 502);

    await admin.from("chat_messages").insert({
      student_id: user.id, role: "coach", body: reply,
      meta: { mode, track, chapter: chapter ?? c.chapter ?? null },
    });

    if (mode === "weekly" || mode === "parent-weekly") {
      const { data: prof } = await admin.from("profiles").select("student_id").eq("student_id", user.id).single();
      if (prof) {
        const d = new Date();
        const monday = new Date(d.setDate(d.getDate() - ((d.getDay() + 6) % 7)));
        await admin.from("weekly_reports").upsert({
          student_id: user.id,
          week_start: monday.toISOString().slice(0, 10),
          body: reply,
        }, { onConflict: "student_id,week_start" });
      }
    }

    return json({ reply });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
