// coach-work — reads a photo of Atharv's rough work and coaches the method.
//
// Deploy:  supabase functions deploy coach-work
// Secret:  supabase secrets set SARVAM_API_KEY=...   (never in the app)
//
// Model:   glm5.3-flash on Sarvam's OpenAI-compatible /v2 endpoint — text and
//          image in, so the photo of his working is read directly. Swap the
//          MODEL constant for gemma4 or deepseekv4.1-flash-1017 if you prefer;
//          both also take inline images.
//
// POST body:
//   { chapter, idx, image_path?, stage: "work" | "check" | "teachback", note? }
//
// Rules it is built to obey:
//   * it never states the final answer, even when it knows it;
//   * it names the exact slip, not "try again";
//   * it offers one alternative method, then one check question;
//   * it ends by asking him to explain it back in his own words;
//   * nothing it says is a mark — marking stays in submit_answer().

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const SYSTEM = `You are a maths coach for an 11-year-old preparing for the Australian
Maths Competition (Upper Primary) and APSMO Division J. He has just sent a photo of his
rough working, or an explanation of his method.

You are given the question and the book's method. Obey these rules without exception:
- Never state the final answer or any part of it. He must produce it.
- If his working is right so far, say exactly what is right, then give the next single step.
- If it has slipped, name the exact line or operation that slipped. Not "check your work".
- Offer one alternative method or equation that reaches the same place by a different road.
- Then pose one short check question that tests the same idea with different numbers.
- Finally ask him to explain the method back in his own words, in two sentences.
- Warm, plain, short: no more than 60 words per field. No praise that is not earned.
- British/Australian spelling. Never mention that you are an AI or a model.

Reply with JSON only, no prose around it:
{"whats_right":"","slip":"","alternative":"","check_question":"","ask_teachback":"","next_focus":""}`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const auth = req.headers.get("Authorization") ?? "";
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const user = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } } },
    );
    const { data: { user: me } } = await user.auth.getUser();
    if (!me) return json({ error: "not signed in" }, 401);

    const { chapter, idx, image_path, stage = "work", note } = await req.json();
    if (!chapter || !idx) return json({ error: "chapter and idx required" }, 400);

    const { data: q } = await admin
      .from("problems")
      .select("prompt, difficulty, chapters(title)")
      .eq("chapter", chapter).eq("idx", idx).single();
    const { data: a } = await admin
      .from("problem_answers")
      .select("method")
      .eq("chapter", chapter).eq("idx", idx).single();
    if (!q) return json({ error: "no such question" }, 404);

    const parts: any[] = [{
      type: "text",
      text: `Question (chapter ${chapter}, ${q.chapters?.title}): ${q.prompt}\n` +
            `Book method: ${a?.method ?? "not recorded"}\n` +
            `Stage: ${stage}${note ? `\nHe says: ${note}` : ""}`,
    }];

    if (image_path) {
      const { data: file } = await admin.storage.from("working").download(image_path);
      if (file) {
        const b64 = btoa(String.fromCharCode(...new Uint8Array(await file.arrayBuffer())));
        const mime = file.type || "image/jpeg";
        parts.push({ type: "image_url", image_url: { url: `data:${mime};base64,${b64}` } });
      }
    }

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.3,
        max_tokens: 800,
        messages: [
          { role: "system", content: SYSTEM },
          { role: "user", content: parts },
        ],
      }),
    });
    if (!r.ok) return json({ error: "model call failed", detail: await r.text() }, 502);

    const body = await r.json();
    const raw = body?.choices?.[0]?.message?.content ?? "{}";
    const feedback = JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1));

    await admin.from("working_reviews").insert({
      student_id: me.id, chapter, idx, image_path, stage, feedback,
      model: MODEL,
    });

    return json(feedback);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
