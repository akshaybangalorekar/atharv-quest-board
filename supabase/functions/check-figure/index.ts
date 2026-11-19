// check-figure — is our drawing as good as the one on the page?
//
// Deploy:  supabase functions deploy check-figure
// Secret:  SARVAM_API_KEY (already set)
//
// POST { question, svg, crop }   crop = base64 png of the figure cut from the page
//   -> { match: true|false, why: "..." }
//
// The drawing we make is compared against the real figure. If it is not faithful
// the app shows the cut-out from the uploaded paper instead: a drawing that only
// nearly matches is worse than the real thing.

const MODEL = "glm5.3-flash";
const ENDPOINT = "https://api.sarvam.ai/v2/chat/completions";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `You are comparing two pictures of the same maths figure: DRAWING (made by us, as SVG text)
and ORIGINAL (cut from the paper the question came from, as an image).

Answer with JSON only:
{"match": true or false, "why": "one short sentence"}

Say true only if the drawing shows the same shape, the same labels, the same numbers and the same
arrangement as the original. A missing label, a different number, a shape of the wrong kind, or a
length that is clearly out of proportion means false. Be strict: a student will work from it.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const { question = "", svg = "", crop = "" } = await req.json();
    if (!svg || !crop) return json({ match: false, why: "nothing to compare" });

    const r = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "api-subscription-key": Deno.env.get("SARVAM_API_KEY")!,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.1,
        max_tokens: 200,
        messages: [
          { role: "system", content: PROMPT },
          {
            role: "user",
            content: [
              { type: "text", text: `Question:\n${question}\n\nDRAWING (SVG):\n${svg}` },
              { type: "image_url", image_url: { url: `data:image/png;base64,${crop}` } },
            ],
          },
        ],
      }),
    });
    if (!r.ok) return json({ match: false, why: "the checker did not answer", error: await r.text() }, 200);

    const body = await r.json();
    const raw = String(body?.choices?.[0]?.message?.content ?? "");
    const a = raw.indexOf("{"), b = raw.lastIndexOf("}");
    if (a < 0 || b <= a) return json({ match: false, why: "unclear answer" }, 200);
    try {
      const parsed = JSON.parse(raw.slice(a, b + 1));
      return json({ match: parsed.match === true, why: String(parsed.why ?? "").slice(0, 200) });
    } catch {
      return json({ match: false, why: "unclear answer" }, 200);
    }
  } catch (e) {
    return json({ match: false, why: String(e) }, 200);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "content-type": "application/json" },
  });
}
