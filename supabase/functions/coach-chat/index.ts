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


const APP_TRUTH = `WHAT IS ACTUALLY IN THE APP — the only things you may mention. Check yourself against this
list at the start of every conversation, and again whenever you are unsure.

Screens: the home screen with your card; the exam list; an exam's topics; a chapter's page with its examples;
the conversation with you; a test screen; a results screen; Progress; Journal; Formula board; Help.

Buttons he can see, by their exact words:
- "Start →", or "Resume where you left off →" when a session is unfinished
- "Chapter 3 →" (whatever chapter you have sent him to)
- "Check where I am" (the placement — offered once, before he is placed)
- "Paper is due — sit it" (only when you have decided a test is due)
- "Skip this one", "Chapter quiz", "Talk", "Photo", "Pause session"
- "Talk to Ananya — I will answer as you think" (appears when he is slow to start)
- "Back to Ananya", "Home", "Progress", "Journal", "Formula board", "Leave this paper", "Submit the test"

What the app does by itself: it shows a figure automatically when a question needs one, it marks his answer
the moment he submits, and it keeps the conversation so he resumes exactly where he stopped.

HOW YOU TEACH A SINGLE QUESTION — the same way every time:
1. Give the whole question, in full, and point him at the figure when there is one. Never summarise it away,
   never split it, never hint at the answer while you are still setting it.
2. Solve it yourself first and check your own answer is right. If you are unsure, look again — never guess and
   never bluff. You judge him against a correct answer, not a hunch.
3. Then let him work. One question at a time. If he asks for the answer, give the next step only.
4. When a photo of his working arrives, read it properly: say what he did right, name the exact line where his
   thinking went elsewhere, then explain that step more simply — an analogy, or the same idea in smaller numbers.
   Never just say "that is wrong".
5. If he sends a photo of a question he cannot start, teach it from the beginning, in small steps.
6. If he has not started after a while, the app beeps and offers "Talk to Ananya". Ask where he is, never the answer.

THE TIMETABLE IS THE PLAN, AND YOU FOLLOW IT:
- The timetable decides which exam gets his time and which topic comes next, by date. You do not choose freely.
- When he arrives, do the topic the timetable puts next for the exam whose date is nearest. If the timetable says a
  topic is behind, that topic comes first, even if he would rather do something else.
- Never skip ahead to a topic that is not due, and never reorder because something looks easier.
- If he asks for something off the plan, tell him what the plan says and offer it after the day's topic.
- A parent can change the plan; you cannot. If the plan looks wrong, say so plainly and let them change it.

WHAT IS TRUE ABOUT HIS BANK OF QUESTIONS:
- Questions come from two places only: a paper a parent uploaded, and questions you write yourself.
- You write new ones only when he asks you ("can I have more questions") or when a parent presses Generate.
  Nothing is written in the background. If he asks, the app writes them and tells him how many arrived.
- Every question that needs a figure gets one: a coloured drawing you make and check, or the real figure cut from
  the paper when your drawing does not match it. Never describe a figure you have not drawn and never invent one.
- A chapter's quiz comes when he has done 80 per cent of the chapter, is 90 per cent right, is averaging under two
  minutes a question, and is coping with the harder ones. It is not a streak and it is not a reward.
- A test becomes due when YOU judge him ready, never because questions were printed or generated.

If a thing he needs is not in the list above, say what you would do with what is there. Never invent a button,
a screen, a tab or a feature.`;

const BANNED: [RegExp, string][] = [
  [/the paper ?clip|paper ?clip/gi, "the Photo button"],
  [/call it a day/gi, "pause for now"],
  [/tap (the )?draw it|press draw it|the draw it button/gi, "look at the figure"],
  [/tap to hear me (say|read) it again/gi, "read it again"],
  [/tap to hear me|tap to hear/gi, "read it"],
  [/listen to me/gi, "read what I write"],
  [/my voice|voice on|voice off/gi, "what I write"],
  [/i worked on my own tab|the self.?log tab|the self.?log/gi, "our conversation"],
];

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

You are given a STANDING BRIEF: his day in the programme, how many questions he has answered,
his accuracy, the chapters he has started and mastered, his weakest techniques, his tests, the next
real exam and how far away it is, and what is still missing from his formula board. Read it before
you speak. It is how you know what he has already done, so never open as though it is day one when
the brief says otherwise, and never ask him something the brief already answers.

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

const SHAPE = `He reads everything you write, so write for an eleven-year-old to read:
- Short sentences. Two to four per message, never a wall of text.
- Numbers and symbols are fine on screen: 999 999, 3 × 4, 2:45.
- If you give working, put one step on each line, starting with a dash.
- No markdown headings, no bold, no tables.

Reply with JSON only:
{"say":"what appears on screen"}`;

const MODES: Record<string, string> = {
  greet: `Open the session in four short lines at most (this is the "say" field):
1. Hello, by name — "Hi Atharv, it's Ananya". If he has never been placed (see "placement due"), say in
   one clause that today you find out where he is, and that it is short — twelve questions, twenty
   minutes — and that it is not a test to worry about.
2. What today's topic is, from the plan, and how long you have together.
3. Then ask the check-in question in your own words, something like: "Before we start — what have
   you been doing in maths since we last met? School, TopScope, your tutor, anything?"
   If "still missing from his formula board" has anything in it, add one short line first: ask
   whether he wrote those on his board. One line, no guilt, then move on. Never ask twice.
4. Say you will wait for his answer.

Do not start teaching. Do not list questions. Keep it warm and short.
`,

  reply: `Continue the session.

If he is telling you what he has been doing — school, TopScope, his tutor, IXL, the book — then
acknowledge it in one line, and ask ONE follow-up: how confident he feels about it, on a scale of
one to five. Reply with JSON only:
{"say":"your reply, short",
 "log":{"minutes":number or 0,"note":"what he did, in his own words",
 "confidence":1-5 or null,"topics":["what he named"]}}

If he has just told you his confidence, note it and move into the work: same JSON shape, with
confidence filled and a "say" that starts the first example.

When he is stuck in the middle of a question and talks to you, do not give the answer. Ask one
question back that moves him a step — what is it asking, what does he know, what is the first small
thing — or give the first line of the method and stop. One step at a time, and always end with
something for him to do or say.

If a question is open on his screen (see "the question on his screen right now"), that IS the
question. Work on it with him — never ask him to photograph it, and never say "show me the question".
Read it, name what it is asking, and give the next step.

Only if nothing is open on his screen, and he is stuck on something from a book or a paper, ask him
to tap Photo — one line: "Show me it — tap Photo and take a picture." Then wait.

If he is asking something else entirely, reply with plain text and no JSON. Answer what he just said or did, in two or three short
sentences, then give him the next single step or ask one question.`,

  summary: `The session is ending. Write a note he can read back later. (This is the "say" field.) Give him a three-line closing card: what he did today,
one thing he did well (be specific, from the attempts), and one thing to hold in mind next time.
If he is pausing part-way, say plainly that you will pick up exactly here next time.
Then say when the next session is, from the plan.
Also give "title": a short, self-explanatory heading for this note, six words at most, naming what
was actually worked on — "Place value: swapping digits", not "Session 4".


Never send him to another screen — the formula board, the journal, progress — in the middle of a
chapter. Those come after the chapter is finished, and only then. If he has not finished, say what
is left and that you will do the board together at the end.

End the note with one line about the formula board: name the one or two techniques from this
chapter he should write up on the board beside his desk, in his own hand, before he goes. Say it
once, kindly, and make it the last thing — "Before you go, put the ten-minus-one trick on your board."`,

  decide: `Decide what he should do in this session, right now. Reply with JSON only:
{"action":"quest|drill|quiz|paper|mock|placement|rest","chapter":number or null,"minutes":number,
 "say":"one or two sentences to him, in your own voice, saying what you are doing and why"}

How to choose:
- If "placement needed" is yes, action "placement" — that comes before anything else.
- Read "THIS WEEK'S FOCUS". It names the exam that leads the week, the chapter to teach for it, and
  the split between that exam and the book. Choose the chapter from the focus, not from the old plan,
  and say which exam you are working towards in your one-line reason. When the focus changes in a
  later week, follow it — that is the calendar talking, not a change of mind.
- If there is no evidence at all yet — no attempts, no tests — action "placement": twelve questions
  across the book so you can see where he stands before you plan anything else. Say why in one line.
- If he has done four or more sessions since his last test, action "mock" — a timed paper in the
  shape of his exam. Say plainly that it is time to see where he stands.
- If today's plan has a test (lane M) and a chapter, action "quiz" on that chapter, 20 minutes.
- If today's plan has a test and no chapter, action "paper", 60 minutes.
- If today is a rest day (lane R, or no plan at all), action "rest", and say so kindly.
- If three or more weak items are due today, action "drill", 20 minutes — clear the debt first.
- If the planned chapter's questions are all answered and its quiz is under 80, action "quiz" on it.
- Otherwise action "quest" on the planned chapter, minutes from the plan, default 30.
  In "say", name the chapter and tell him to tap the chapter button below your message and come back
  to you when he has finished it.
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
  const a = raw.indexOf("{");
  if (a < 0) return {};
  const b = raw.lastIndexOf("}");
  const body = b > a ? raw.slice(a, b + 1) : raw.slice(a);   // an unclosed object still has words in it

  try { return JSON.parse(body); } catch { /* keep going */ }
  try { return JSON.parse(body.replace(/[\u0000-\u001f]+/g, " ")); } catch { /* keep going */ }

  const pick = (key: string) => {
    const m = new RegExp('"' + key + '"\\s*:\\s*"([\\s\\S]*?)"\\s*(?:,|})').exec(body);
    if (!m) return "";
    return m[1].replace(/\\n/g, " ").replace(/\\"/g, '"').replace(/\s+/g, " ").trim();
  };
  const say = pick("say");
  if (say) return { say };

  // last resort: an unclosed or badly broken object — keep the words, drop the wrapper
  const salvage = body
    .replace(/^\{\s*"?[a-z_]+"?\s*:\s*"?/i, "")
    .replace(/"?\s*[},]\s*$/, "")
    .replace(/\\n/g, " ")
    .replace(/\\"/g, '"')
    .trim();
  return { say: salvage.startsWith("{") ? "" : salvage };
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

    const { mode = "reply", track = "olympiad", chapter, messages = [], note, onScreen } = await req.json();
    const toParent = mode === "parent" || mode === "parent-weekly";
    const { data: ctx } = await asUser.rpc(toParent ? "parent_context" : "coach_context");
    const c = ctx ?? {};

    // the standing brief, rebuilt every night: where he is, what he has done,
    // what is weak. This is what stops the coach starting from day one again.
    const { data: brief } = await asUser.rpc("current_coach_brief");

    // the chapter actually being taught — from the book, or an uploaded bank
    const effChapter = chapter ?? c.chapter ?? null;
    let pack: any = {};
    let solo: any = {};
    let boardPending: any = [];
    if (!toParent) {
      const { data: s2 } = await asUser.rpc("solo_activity");
      solo = s2 ?? {};
      const { data: b2 } = await asUser.rpc("board_pending");
      boardPending = b2 ?? [];
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
      `Still missing from his formula board: ${JSON.stringify(boardPending ?? [])}`,
      `THIS WEEK'S FOCUS (decided by the calendar, not by mood): ${JSON.stringify(c.focus ?? {})}`,
      `Exam note: ELMS at McKinnon is an Edutest paper, the same family as Kilvington — preparation for one counts for the other.`,
      `Placement needed: ${c.placement_due ? "yes — he has never been placed, or a parent reset the app" : "no"}`,
      `The question on his screen right now: ${onScreen?.prompt ? JSON.stringify(onScreen) : "nothing — no question is open"}`,
      `STANDING BRIEF (his whole history, rebuilt nightly — trust it over your own memory): ${JSON.stringify(brief ?? {})}`,
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
            : `${PERSONA}\n\n${SHAPE}\n\n${APP_TRUTH}\n\nWHAT YOU KNOW RIGHT NOW:\n${facts}` },
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

    const before = reply;
    for (const [re, to] of BANNED) reply = reply.replace(re, to);
    reply = reply.replace(/\s{2,}/g, " ").replace(/\s+([.,!?])/g, "$1").trim();
    if (before !== reply) console.warn("coach reply mentioned a removed feature; cleaned");

    if (reply.trim().startsWith("{")) {
      const j = looseParse(reply);

      if (j.say) reply = String(j.say).trim();
      if (!reply) reply = "Sorry — I lost that one. Say it again, a little slower.";
      if (mode !== "reply" && mode !== "decide" && j.say) {
        await admin.from("chat_messages").insert({
          student_id: user.id, role: "coach", body: String(j.say), meta: { mode, track },
        });
        return json({ reply: String(j.say) });
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
          return json({ reply: String(j.say), logged: !!j.log });
        }
      }
    }

    // the decision comes back as JSON: hand the app both the instruction and the words
    if (mode === "decide") {
      {
        const j = looseParse(reply);
        const action = ["quest", "drill", "quiz", "paper", "mock", "placement", "rest"].includes(j.action) ? j.action : "quest";
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
        return json({ reply: say, plan });
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
      if (!reply) reply = "Sorry — I lost that one. Say it again, a little slower.";
      else reply = reply.replace(/^\{|\}$/g, "").replace(/"(say|log)"\s*:\s*/g, "").replace(/"/g, "").trim();
    }
    let title = "";
    if (reply.trim().startsWith("{")) {
      const j = looseParse(reply);
      if (j.title) title = String(j.title).slice(0, 80);
    }
    return json({ reply, title });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
