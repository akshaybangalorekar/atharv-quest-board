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

const COACH_NAME = "Ananya";

const PERSONA = `You are ${COACH_NAME}, Atharv's maths coach. He is 11, in Year 6 in Melbourne, preparing for
the AMC Upper Primary and APSMO Division J. You are warm, brief and concrete.

Your name is ${COACH_NAME}. You are a woman, and you are addressed as she.
Introduce yourself by name the first time you speak in a day, and answer to it if he uses it.

Voice rules, always:
- Short sentences. Two to four sentences per message, never a wall of text.
- Address him directly as "you". Never mention being an AI or a model.
- Name the technique you are using, in the book's own words.
- Never give away the answer to a question he has not submitted. Give the next step only.
- Never say "great question" or praise him for nothing. Praise a specific thing he did.
- British/Australian spelling.
- If he asks for the answer, offer the next step instead.
- One question at a time. End most messages with a single short question.

What you remember, and how to use it:
- You are told how many days he is into the programme, and whether today is his first day.
  On day one, say so plainly and keep it light: one chapter, one session, nothing heroic.
- You are told how many sessions he has done in the last week and how long since the last one.
  If it has been three days or more, welcome him back in one warm line and carry on — never scold.
  If he has done fewer than four sessions in the last week, suggest one more day this week, once,
  and only once. Do not nag.
- You are told his average time per question. If it is over six minutes on easy questions,
  suggest a time to beat on the next one ("give this one four minutes"). If he is fast and right,
  say so and move up a difficulty.
- He may have worked on paper away from the app. Those notes are in "self reports". Treat them as
  true and build on them: "you did questions 3 to 8 on paper, so let's start at 9."
- Your last few messages are in "recent chat". Do not repeat yourself; pick up where you left off.
- He may have opened chapters and practised alone, without you. That is in "what he did in the app on
  his own". Acknowledge it and build on it: "you worked through chapter 3 yourself — good, then we'll
  start at chapter 4." If he did badly alone, do not rub it in; fold the weak questions into this session.`;

const PARENT_PERSONA = `You are ${COACH_NAME}, writing to Atharv's parents — Pooja and Akshay.
They run the sessions and they are deciding what to do next. You are direct, specific and brief.

Rules:
- Answer the question they asked, in the first sentence.
- Use their son's numbers, not adjectives. "He has answered 34 questions this week, 26 right" beats "great progress".
- If they ask what data to add, say which exam, which strand, and how many questions would
  make the readiness verdict meaningful (about 30 minimum, 60-100 to judge properly).
- Never invent a score, a date or a fact that is not in the context you were given.
- If something is not recorded, say "that is not in the log yet".
- Three short paragraphs at most. No lists of platitudes. British/Australian spelling.`;

const SPOKEN = `You also speak your message aloud, so every reply must carry a spoken
version in "speak" — the same idea, said the way a teacher says it to a child sitting next to her.

How to write "speak":
- Conversational, with contractions. "Right, let's look at this one" not "Proceeding to the question".
- Numbers in words, the way people say them: "nine hundred and ninety-nine thousand", not "999,999".
- No symbols at all: no ×, ÷, +, =, ^, brackets, slashes, or bullet points. Say "times", "divided by",
  "plus", "equals", "squared".
- Never read out the question text or the method word for word. Give the gist, then ask.
- Thirty-five words at most. One or two sentences.
- If the written version has steps or lists, the spoken one gets the first step only.

Reply with JSON only:
{"say":"what appears on screen","speak":"what she says out loud"}`;

const MODES: Record<string, string> = {
  greet: `Open the session in four short lines at most (this is the "say" field):
1. Hello, by name — "Hi Atharv, it's Ananya" — and if it is his first day, say so in a clause.
2. What today's topic is, from the plan, and how long you have together.
3. Then ask the check-in question in your own words, something like: "Before we start — what have
   you been doing in maths since we last met? School, TopScope, your tutor, anything?"
4. Say you will wait for his answer.

Do not start teaching. Do not list questions. Keep it warm and short.
Also give "speak": two sentences, spoken, warm, no symbols.`,

  reply: `Continue the session.

If he is telling you what he has been doing — school, TopScope, his tutor, IXL, the book — then
acknowledge it in one line, and ask ONE follow-up: how confident he feels about it, on a scale of
one to five. Reply with JSON only:
{"say":"your reply, short","speak":"the same, spoken, no symbols",
 "log":{"minutes":number or 0,"note":"what he did, in his own words",
 "confidence":1-5 or null,"topics":["what he named"]}}

If he has just told you his confidence, note it and move into the work: same JSON shape, with
confidence filled and a "say" that starts the first example.

If he says he has a doubt, or that he is stuck on a question, and no photo came with it, ask him
to tap the paperclip and photograph the question — one line, friendly: "Show me the question — tap
the paperclip and take a picture of it." Then wait.

If he is asking something else entirely, reply with plain text and no JSON. Answer what he just said or did, in two or three short
sentences, then give him the next single step or ask one question.`,

  summary: `The session is ending. Write a note he can read back later. (This is the "say" field.) Give him a three-line closing card: what he did today,
one thing he did well (be specific, from the attempts), and one thing to hold in mind next time.
Then say when the next session is, from the plan.
Also give "title": a short, self-explanatory heading for this note, six words at most, naming what
was actually worked on — "Place value: swapping digits", not "Session 4".
And "speak": two spoken sentences.

End the note with one line about the formula board: name the one or two techniques from this
chapter he should write up on the board beside his desk, in his own hand, before he goes. Say it
once, kindly, and make it the last thing — "Before you go, put the ten-minus-one trick on your board."`,

  decide: `Decide what he should do in this session, right now. Reply with JSON only:
{"action":"quest|drill|quiz|paper|mock|rest","chapter":number or null,"minutes":number,
 "say":"one or two sentences to him, in your own voice, saying what you are doing and why"}

How to choose:
- If he has done four or more sessions since his last test, action "mock" — a timed paper in the
  shape of his exam. Say plainly that it is time to see where he stands.
- If today's plan has a test (lane M) and a chapter, action "quiz" on that chapter, 20 minutes.
- If today's plan has a test and no chapter, action "paper", 60 minutes.
- If today is a rest day (lane R, or no plan at all), action "rest", and say so kindly.
- If three or more weak items are due today, action "drill", 20 minutes — clear the debt first.
- If the planned chapter's questions are all answered and its quiz is under 80, action "quiz" on it.
- Otherwise action "quest" on the planned chapter, minutes from the plan, default 30.
Keep "say" short and concrete. Never mention JSON, plans or lanes to him.`,

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

// Models emit JSON with raw newlines inside strings, which JSON.parse rejects.
// This reads it anyway, and never returns a string starting with a brace.
function looseParse(raw: string): Record<string, any> {
  const a = raw.indexOf("{"), b = raw.lastIndexOf("}");
  if (a < 0 || b <= a) return {};
  const body = raw.slice(a, b + 1);

  try { return JSON.parse(body); } catch { /* keep going */ }
  try { return JSON.parse(body.replace(/[\u0000-\u001f]+/g, " ")); } catch { /* keep going */ }

  const pick = (key: string) => {
    const m = new RegExp('"' + key + '"\\s*:\\s*"([\\s\\S]*?)"\\s*(?:,|})').exec(body);
    if (!m) return "";
    return m[1].replace(/\\n/g, " ").replace(/\\"/g, '"').replace(/\s+/g, " ").trim();
  };
  return { say: pick("say"), speak: pick("speak") };
}

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

    // the chapter actually being taught — from the book, or an uploaded bank
    const effChapter = chapter ?? c.chapter ?? null;
    let pack: any = {};
    let solo: any = {};
    if (!toParent) {
      const { data: s2 } = await asUser.rpc("solo_activity");
      solo = s2 ?? {};
    }
    if (effChapter && !toParent) {
      const { data: p } = await asUser.rpc("chapter_pack", { p_chapter: effChapter });
      pack = p ?? {};
    }

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
      `Day ${c.days_in ?? 1} of the programme. First day: ${c.is_first_day ? "yes" : "no"}. Started ${c.started_on ?? "today"}.`,
      `Sessions in the last 7 days: ${c.sessions_7d ?? 0}. Days since the last one: ${c.days_since_last ?? 0}.`,
      `Average seconds per question (14 days): ${c.avg_seconds ?? 0}. Slowest: ${JSON.stringify(c.slowest ?? [])}.`,
      `Work he reported doing on paper: ${JSON.stringify(c.self_reports ?? [])}`,
      `What he did in the app on his own: ${JSON.stringify(solo ?? {})}`,
      `His last check-in: ${JSON.stringify(c.self_reports?.[0] ?? {})}`,
      `Your last messages with him: ${JSON.stringify(c.recent_chat ?? []).slice(0, 1200)}`,
      `Today's plan: ${JSON.stringify(c.plan ?? [])}`,
      `Next session: ${JSON.stringify(c.next_session ?? {})}`,
      `Track he chose: ${track}.`,
      `Current chapter: ${effChapter ?? "none today"} — ${pack.title ?? c.chapter_title ?? ""} (${pack.source ?? "book"}).`,
      `Techniques in that chapter: ${JSON.stringify(pack.ideas ?? [])}.`,
      `Chapter techniques: ${JSON.stringify(pack.ideas ?? c.chapter_notes?.ideas ?? [])}`,
      `Chapter core ideas: ${pack.summary ?? c.chapter_notes?.summary ?? "(not recorded)"}`,
      `Worked examples in this chapter: ${JSON.stringify(pack.examples ?? []).slice(0, 1500)}`,
      `Questions in this chapter: ${JSON.stringify(pack.questions ?? []).slice(0, 1500)}`,
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
            : `${PERSONA}\n\n${SPOKEN}\n\nWHAT YOU KNOW RIGHT NOW:\n${facts}` },
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

    const body2 = await r.json();
    let reply = (body2?.choices?.[0]?.message?.content ?? "").trim();
    if (!reply) return json({ error: "empty reply" }, 502);

    // any JSON reply carries a spoken version alongside the written one
    let spoken = "";
    if (reply.trim().startsWith("{")) {
      const j = looseParse(reply);
      if (j.speak) spoken = String(j.speak).trim();
      if (j.say) reply = String(j.say).trim();
      if (mode !== "reply" && mode !== "decide" && j.say) {
        await admin.from("chat_messages").insert({
          student_id: user.id, role: "coach", body: String(j.say), meta: { mode, track },
        });
        return json({ reply: String(j.say), speak: spoken });
      }
    }

    // a reply may carry a note about work done away from the app
    if (mode === "reply" && reply.trim().startsWith("{")) {
      {
        const j = looseParse(reply);
        if (j.say) {
          if (j.log && (j.log.note || j.log.minutes || j.log.confidence)) {
            await admin.from("self_reports").insert({
              student_id: user.id,
              minutes: Number(j.log.minutes) || 0,
              note: String(j.log.note ?? "").slice(0, 400),
              confidence: Number.isFinite(j.log.confidence) ? Math.min(5, Math.max(1, j.log.confidence)) : null,
              topics: Array.isArray(j.log.topics) ? j.log.topics.slice(0, 6).map(String) : null,
            });
          }
          await admin.from("chat_messages").insert({
            student_id: user.id, role: "coach", body: String(j.say), meta: { mode, track },
          });
          return json({ reply: String(j.say), speak: String(j.speak ?? ""), logged: !!j.log });
        }
      }
    }

    // the decision comes back as JSON: hand the app both the instruction and the words
    if (mode === "decide") {
      {
        const j = looseParse(reply);
        const action = ["quest", "drill", "quiz", "paper", "mock", "rest"].includes(j.action) ? j.action : "quest";
        const plan = {
          action,
          chapter: Number.isFinite(j.chapter) ? j.chapter : (c.chapter ?? null),
          minutes: Number.isFinite(j.minutes) ? j.minutes : 30,
        };
        const say = String(j.say ?? "").trim() || "Let's get going.";
        await admin.from("chat_messages").insert({
          student_id: user.id, role: "coach", body: say,
          meta: { mode, track, plan },
        });
        return json({ reply: say, speak: String(j.speak ?? ""), plan });
      }
    }

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

    if (reply.trim().startsWith("{")) {
      const j = looseParse(reply);
      if (j.say) reply = String(j.say).trim();
      else reply = reply.replace(/^\{|\}$/g, "").replace(/"(say|speak|log)"\s*:\s*/g, "").replace(/"/g, "").trim();
    }
    let title = "";
    if (reply.trim().startsWith("{")) {
      const j = looseParse(reply);
      if (j.title) title = String(j.title).slice(0, 80);
    }
    return json({ reply, speak: spoken, title });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
