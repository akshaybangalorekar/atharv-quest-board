// draw-figure — the coach drawing on the board.
//
// Deploy:  supabase functions deploy draw-figure
// Secret:  SARVAM_API_KEY (already set)
//
// POST { chapter, kind: "example" | "question", n?, idx? }
//   -> { svg, cached }
//
// It draws one small figure for one question, and keeps it, so the same figure
// is never drawn twice. Nothing it draws replaces the question: it is a sketch
// to think with, not the source of truth.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `Draw a small, clear diagram for this maths question, as SVG.

Rules:
- viewBox "0 0 320 220", no scripts, no external images, no <style> blocks.
- Plain strokes, 2px, one accent colour at most, white background, generous spacing.
- Label points and lengths with <text> at font-size 12.
- It must be geometrically honest: right angles look like right angles, equal sides look equal.
  Count squares carefully. If you cannot draw it faithfully, return an empty string.
- No title, no answer, no workings — just the figure.

Reply with the SVG only, starting with <svg.`;

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

    const { chapter, kind = "question", n = null, idx = null } = await req.json();
    if (!chapter) return json({ error: "chapter required" }, 400);

    const table = kind === "example" ? "examples" : "problems";
    const keyCol = kind === "example" ? "n" : "idx";
    const keyVal = kind === "example" ? n : idx;
    if (!keyVal) return json({ error: "which one?" }, 400);

    const { data: row } = await admin.from(table)
      .select(`${keyCol}, prompt, diagram_svg`).eq("chapter", chapter).eq(keyCol, keyVal).single();
    if (!row) return json({ error: "no such item" }, 404);
    if (row.diagram_svg) return json({ svg: row.diagram_svg, cached: true });

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.2,
        max_tokens: 1600,
        messages: [
          { role: "system", content: PROMPT },
          { role: "user", content: row.prompt },
        ],
      }),
    });
    if (!r.ok) return json({ error: "model call failed", detail: await r.text() }, 502);

    const body = await r.json();
    const raw = body?.choices?.[0]?.message?.content ?? "";
    const start = raw.indexOf("<svg");
    const end = raw.lastIndexOf("</svg>");
    if (start < 0 || end < 0) return json({ svg: "", note: "no figure for this one" });
    const svg = raw.slice(start, end + 6);

    await admin.from(table).update({ diagram_svg: svg }).eq("chapter", chapter).eq(keyCol, keyVal);
    return json({ svg, cached: false });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
