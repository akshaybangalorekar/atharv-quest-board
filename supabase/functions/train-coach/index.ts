// train-coach — read the material, keep it, and check every question.
//
// Two jobs, one function:
//   mode "fetch"  — pull the public pages of the active sources, keep their text as chunks
//   mode "upload" — keep the text of pages already read from uploaded papers
//   mode "verify" — check every unverified question: can it be answered from its own words?
//
// Nothing here publishes anything. The material is stored for this child only, and every
// chunk keeps the URL and the date it was read, so a parent can see where a claim came from.
//
// Secrets: SARVAM_API_KEY

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

/* strip a page down to readable text */
async function sha(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function textOf(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<nav[\s\S]*?<\/nav>/gi, " ")
    .replace(/<footer[\s\S]*?<\/footer>/gi, " ")
    .replace(/<\/(p|div|li|h[1-6]|tr|section)>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&#\d+;/g, " ")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/* paragraphs, gathered into passages of a readable size */
function chunk(text: string, size = 700): string[] {
  const paras = text.split(/\n+/).map((p) => p.trim()).filter((p) => p.length > 40);
  const out: string[] = [];
  let cur = "";
  for (const p of paras) {
    if ((cur + " " + p).length > size && cur) { out.push(cur.trim()); cur = p; }
    else cur += (cur ? " " : "") + p;
  }
  if (cur.trim()) out.push(cur.trim());
  return out.slice(0, 60);
}

async function ask(system: string, user: string, temperature = 0): Promise<string> {
  const r = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "content-type": "application/json", "api-subscription-key": Deno.env.get("SARVAM_API_KEY")! },
    body: JSON.stringify({ model: MODEL, temperature, messages: [
      { role: "system", content: system }, { role: "user", content: user }] }),
  });
  if (!r.ok) return "";
  const b = await r.json();
  return (b?.choices?.[0]?.message?.content ?? "").trim();
}


const FIND = `You suggest websites that hold real maths material for an 11-year-old preparing for Australian
competitions and scholarship tests: official providers first, then well-known free maths sites.

Rules:
- Only sites that actually exist and are free to read.
- No forums, no social media, no video sites, no paywalled papers, no search pages.
- One line each, and a reason in six words.

Reply with JSON only:
{"sites":[{"name":"...","url":"https://...","why":"..."}]}`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try { return await handle(req); }
  catch (e) { return json({ error: "the trainer failed", detail: String((e as Error)?.message ?? e) }); }
});

async function handle(req: Request) {
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return json({ error: "not signed in" }, 401);

  const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: who } = await supa.auth.getUser(auth.replace(/^Bearer\s+/i, ""));
  const user = who?.user;
  if (!user) return json({ error: "not signed in" }, 401);

  const { data: ownProfile } = await supa.from("profiles").select("student_id").eq("student_id", user.id).maybeSingle();
  let student = user.id;
  if (!ownProfile) {
    const { g } = { g: null } as any;
    const { data: guardian } = await supa.from("guardians").select("student_id").eq("parent_id", user.id).limit(1).maybeSingle();
    if (guardian?.student_id) student = guardian.student_id;
  }

  // one row per run, so "it ran" is a fact and not a claim
  const { data: jobId } = await supa.rpc("start_job", { p_kind: "train" });


  let body: any = {};
  try { body = await req.json(); } catch (_) {}
  let mode = body?.mode ?? "all";
  await supa.from("jobs").update({ kind: `train:${mode}` }).eq("id", jobId);

  // "all" is the single path: uploads first, then the sources, then the check
  if (mode === "all") {
    const inner = async (m: string) => {
      const r = await handle(new Request(req.url, {
        method: "POST",
        headers: { authorization: auth, "content-type": "application/json" },
        body: JSON.stringify({ mode: m }),
      }));
      try { return await r.json(); } catch { return {}; }
    };
    const up = await inner("upload");
    const fe = await inner("fetch");
    const ve = await inner("verify");
    return json({
      mode: "all",
      uploads: up?.papers ?? 0,
      fetched: fe?.fetched ?? 0,
      checked: ve?.checked ?? 0,
      failed: ve?.failed ?? [],
    });
  }

  // ---------------------------------------------------------------- verify --
  if (mode === "verify") {
    const { data: rows } = await supa.from("problems")
      .select("chapter, idx, prompt, options, diagram_svg")
      .in("status", ["draft"]).limit(40);

    const checked: Array<{ chapter: number; idx: number; ok: boolean; why: string }> = [];
    for (const r of rows ?? []) {
      const q = String(r.prompt ?? "");
      const pointsAtFigure = /\b(picture|diagram|figure|table|chart|graph|drawing|shown|below)\b/i.test(q);
      const hasFigure = !!r.diagram_svg;

      const v = await checkQuestion(q, hasFigure);
      await supa.rpc("set_question_status", {
        p_chapter: r.chapter, p_idx: r.idx,
        p_status: v.ok ? "provisional" : "failed", p_note: v.ok ? null : v.why,
      });
      checked.push({ chapter: r.chapter, idx: r.idx, ok: v.ok, why: v.why });
    }
    await supa.rpc("finish_job", {
    p_id: jobId, p_ok: true,
    p_detail: { checked: checked.length, held_back: checked.filter((c) => !c.ok).length },
    p_error: null,
  });
  return json({ mode, checked: checked.length, failed: checked.filter((c) => !c.ok) });
  }

  // --------------------------------------------------------------- uploads --
  if (mode === "upload") {
    const { data: papers } = await supa.from("papers").select("id, title, url, pages").eq("student_id", student);
    let kept = 0, skipped = 0;
    for (const p of papers ?? []) {
      const { data: pages } = await supa.from("paper_pages")
        .select("page_no, text").eq("paper_id", p.id).order("page_no");
      const all = (pages ?? []).map((x: any) => String(x.text ?? "")).join("\n").trim();
      if (all.length < 80) continue;
      // the questions taken from this paper are material too: she should be able to read them
      const { data: qs } = await supa.from("problems")
        .select("chapter, idx, prompt, options").eq("paper_id", p.id).order("chapter").order("idx");
      const qText = (qs ?? []).map((q: any) =>
        `Q: ${q.prompt}${Array.isArray(q.options) ? ` Options: ${q.options.join(" / ")}` : ""}`).join("\n\n");

      const whole = all + (qText ? "\n\n" + qText : "");
      const chunks = chunk(whole).map((b) => ({ body: b, topic: p.title ?? "uploaded paper" }));
      const { data: upRes, error: upErr } = await supa.rpc("store_doc", {
        p_kind: "upload", p_title: p.title ?? `paper ${p.id}`, p_url: p.url ?? null,
        p_source_id: null, p_chunks: chunks, p_hash: await sha(whole),
      });
      if (!upErr) { kept++; if ((upRes as any)?.stored === false) skipped++; }
    }
    await supa.rpc("finish_job", { p_id: jobId, p_ok: true, p_detail: { kept, unchanged: skipped }, p_error: null });
    return json({ mode, papers: kept, unchanged: skipped });
  }

  // -------------------------------------------------------------- discover --
  if (mode === "discover") {
    const { data: have } = await supa.from("training_sources").select("name, url");
    const known = (have ?? []).map((x: any) => String(x.url ?? "")).join("\n");
    const raw = await ask(FIND, `Already on the list:\n${known || "(nothing yet)"}\n\nSuggest up to six more.`);
    const m = raw.match(/\{[\s\S]*\}/);
    let sites: Array<{ name: string; url: string; why: string }> = [];
    try { sites = JSON.parse(m ? m[0] : "{}").sites ?? []; } catch (_) {}

    const added: Array<Record<string, unknown>> = [];
    const knownHosts = new Set((have ?? []).map((x: any) => {
      try { return new URL(String(x.url)).host.replace(/^www\./, ""); } catch { return ""; }
    }));
    const BAD = /(google|bing|facebook|instagram|youtube|reddit|quora|pinterest|twitter|x\.com|tiktok|amazon|ebay)/i;

    for (const site of sites.slice(0, 6)) {
      const url = String(site.url ?? "");
      if (!/^https:\/\//.test(url)) continue;
      let host = "";
      try { host = new URL(url).host.replace(/^www\./, ""); } catch { continue; }
      if (!host || knownHosts.has(host) || BAD.test(host)) continue;

      // it must actually answer, and actually hold words
      try {
        const r = await fetch(url, { headers: { "user-agent": "QuestCoach/1.0 (family study app)" } });
        if (!r.ok) continue;
        const text = textOf(await r.text());
        if (text.length < 600) continue;
        const maths = (text.match(/maths?|mathemat|number|fraction|algebra|geometry|problem/gi) ?? []).length;
        if (maths < 8) continue;                       // not a maths page

        const { error } = await supa.rpc("add_training_source", {
          p_name: String(site.name ?? host).slice(0, 80), p_url: url, p_kind: "popular",
          p_family: "general", p_note: String(site.why ?? "").slice(0, 120), p_found_by: "coach",
        });
        if (error) continue;
        knownHosts.add(host);
        added.push({ name: site.name, url, why: site.why });
      } catch (_) { /* a site that does not answer is not added */ }
    }
    return json({ mode, proposed: sites.length, added });
  }

  // ----------------------------------------------------------------- fetch --
  const { data: sources } = await supa.from("training_sources").select("id, name, url, family").eq("active", true);
  const done: Array<Record<string, unknown>> = [];

  for (const s of sources ?? []) {
    if (!s.url) continue;
    try {
      const r = await fetch(s.url, { headers: { "user-agent": "QuestCoach/1.0 (family study app)" } });
      if (!r.ok) { done.push({ source: s.name, ok: false, status: r.status }); continue; }
      const raw = await r.text();
      const text = textOf(raw);
      if (text.length < 200) { done.push({ source: s.name, ok: false, reason: "no readable text" }); continue; }

      const chunks = chunk(text).map((b) => ({ body: b, topic: s.name, family: s.family }));
      const hash = await sha(text);
      const { data: stored, error: storeErr } = await supa.rpc("store_doc", {
        p_kind: "web", p_title: s.name, p_url: s.url, p_source_id: s.id, p_chunks: chunks, p_hash: hash,
      });
      if (storeErr) { done.push({ source: s.name, ok: false, reason: storeErr.message.slice(0, 120) }); continue; }
      const fresh = (stored as any)?.stored !== false;
      done.push({ source: s.name, ok: true, chunks: fresh ? chunks.length : 0, unchanged: !fresh });
    } catch (e) {
      done.push({ source: s.name, ok: false, reason: String((e as Error)?.message ?? e).slice(0, 120) });
    }
  }

  // reading the sources fills the bank: this is not the parent pressing Generate
  let filled = { strands: 0, made: 0 };
  if (mode === "fetch" || mode === "all") {
    try { filled = await fillFromMaterial(supa, { perStrand: 3, maxStrands: 6 }); }
    catch (e) { console.error("fill failed:", String((e as Error)?.message ?? e)); }
  }

  const failed = done.filter((d) => !d.ok);
  await supa.rpc("finish_job", {
    p_id: jobId, p_ok: failed.length === 0,
    p_detail: { fetched: done.length - failed.length, failed: failed.length, generated: filled.made, sources: done },
    p_error: failed.length ? `${failed.length} source(s) could not be read` : null,
  });
  return json({ mode, fetched: done.filter((d) => d.ok).length, generated: filled.made, sources: done });
}
