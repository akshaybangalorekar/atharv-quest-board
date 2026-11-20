// draw-figure — the coach drawing on the board.
//
// Deploy:  supabase functions deploy draw-figure
// Secret:  SARVAM_API_KEY (already set)
//
// POST { chapter, kind: "example" | "question", n?, idx?, question?, hint? }
//   -> { svg, cached, checked }
//
// It draws one figure for one question, in colour, at a decent size, then checks
// its own work: a second pass reads the question against the drawing and answers
// yes or no. A drawing that fails the check is thrown away and nothing is stored,
// so the app falls back to the real page crop. A wrong picture is worse than the
// original page.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ask } from "./_shared/mod.ts";

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `You are drawing the figure that belongs to a maths question, as an SVG.

This drawing is what the student will look at instead of the page, so it must be right.

Rules:
- viewBox "0 0 480 340". Use the whole canvas; do not crowd the figure into a corner.
- Colour it. Fill shapes with soft colour (use fills like #e8f0ff, #fff4d6, #e9f7ec, #fde8ef)
  and draw their outlines in a darker shade of the same colour. Axes, labels and leaders are #33415c.
  At most three colours, chosen to help the eye, never to decorate.
- Line width 2. Font size 15 for labels, 13 for small ones. font-family="system-ui, sans-serif".
- Label everything the question names: points (A, B, C), lengths ("7 cm"), angles ("40°"),
  values on bars and axes. A label the question mentions must appear in the drawing.
- Be geometrically honest. Right angles look like right angles — mark them with a small square.
  Equal sides look equal. A rectangle is not a parallelogram. A bar chart's bars are in proportion
  to its numbers. Count squares and intervals carefully.
- Include the axes, scales and gridlines for charts; the sector labels and a legend for pie charts;
  the rows, columns and numbers for tables. Draw the numbers the question gives.
- No title, no answer, no workings, no watermark — just the figure.

If the question cannot be drawn faithfully from what it says, reply with exactly: NONE

Otherwise reply with the SVG only, starting with <svg and ending with </svg>.`;

const CHECK = `You are checking a drawing against the question it belongs to.

Answer with one word: YES if the drawing shows every element the question names and nothing false.
NO if a label is missing, a number is wrong, a shape is not what the question says, or a length or
angle is clearly not in proportion.

Be strict. A student will read this drawing instead of the page.`;

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

    const { chapter, kind = "question", n = null, idx = null, question = null } = await req.json();
    if (!chapter) return json({ error: "chapter required" }, 400);

    const table = kind === "example" ? "examples" : "problems";
    const keyCol = kind === "example" ? "n" : "idx";
    const keyVal = kind === "example" ? n : idx;
    if (!keyVal) return json({ error: "which one?" }, 400);

    const { data: row } = await admin.from(table)
      .select(`${keyCol}, prompt, diagram_svg`).eq("chapter", chapter).eq(keyCol, keyVal).single();
    if (!row) return json({ error: "no such item" }, 404);
    if (row.diagram_svg) return json({ svg: row.diagram_svg, cached: true, checked: true });

    const text = String(question ?? row.prompt ?? "");

    // first pass: draw it
    const drawn = await ask([
      { role: "system", content: PROMPT },
      { role: "user", content: `The question:\n\n${text}` },
    ], 0.25, 3000);

    if (!drawn || /^\s*NONE\s*$/i.test(drawn)) return json({ svg: "", note: "not drawable from the words" });
    const start = drawn.indexOf("<svg"), end = drawn.lastIndexOf("</svg>");
    if (start < 0 || end < 0) return json({ svg: "", note: "no figure for this one" });
    const svg = drawn.slice(start, end + 6);
    if (svg.length < 200) return json({ svg: "", note: "the drawing came back empty" });

    // second pass: does it show what the question says?
    const verdict = await ask([
      { role: "system", content: CHECK },
      { role: "user", content: `Question:\n${text}\n\nDrawing (SVG):\n${svg}` },
    ], 0.1, 20);

    const ok = /^\s*YES/i.test(String(verdict ?? ""));
    if (!ok) return json({ svg: "", note: "the drawing did not pass its own check", checked: false });

    await admin.from(table).update({ diagram_svg: svg }).eq("chapter", chapter).eq(keyCol, keyVal);
    return json({ svg, cached: false, checked: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

async function ask(messages: unknown[], temperature: number, maxTokens: number) {
  const r = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
    },
    body: JSON.stringify({ model: MODEL, temperature, max_tokens: maxTokens, messages }),
  });
  if (!r.ok) return "";
  const body = await r.json();
  return String(body?.choices?.[0]?.message?.content ?? "");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
