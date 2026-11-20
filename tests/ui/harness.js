/* tests/ui/harness.js — what every screen test is built on.
   Loaded into a copy of index.html, after a stub of the database, before the app's own script. */

window.__calls = [];          // every rpc and function call the page makes
window.__fixtures = {};       // per-test answers for rpc calls

function rpc(name) {
  return function (args) {
    window.__calls.push({ rpc: name, args });
    const f = window.__fixtures[name];
    return Promise.resolve({ data: typeof f === "function" ? f(args) : (f ?? null), error: null });
  };
}

window.supabase = {
  createClient: () => ({
    from(name) {
      const q = {
        select: () => q, eq: () => q, order: () => q, limit: () => q, neq: () => q,
        in: () => q, not: () => q, gte: () => q, lte: () => q,
        maybeSingle: () => Promise.resolve({ data: null, error: null }),
        single: () => Promise.resolve({ data: null, error: null }),
        insert: () => Promise.resolve({ error: null }),
        upsert: () => Promise.resolve({ error: null }),
        update: () => Promise.resolve({ error: null }),
        delete: () => Promise.resolve({ error: null }),
        then: (a) => Promise.resolve({ data: [], error: null }).then(a),
      };
      return q;
    },
    rpc: (name, args) => rpc(name)(args),
    auth: {
      getUser: () => Promise.resolve({ data: { user: { id: "kid", email: "a@b.c" } } }),
      getSession: () => Promise.resolve({ data: { session: { user: { id: "kid" } } } }),
      onAuthStateChange: () => {},
      signOut: () => Promise.resolve({}),
    },
    functions: {
      invoke: (name, opts) => {
        window.__calls.push({ fn: name, args: opts?.body });
        const f = window.__fixtures["fn:" + name];
        return Promise.resolve({ data: typeof f === "function" ? f(opts?.body) : (f ?? {}), error: null });
      },
    },
    storage: { from: () => ({ upload: () => Promise.resolve({}), download: () => Promise.resolve({ data: null }), remove: () => Promise.resolve({}) }) },
  }),
};

/* ---------- small helpers the cases use ---------- */
window.T = {
  wait: (ms = 60) => new Promise((r) => setTimeout(r, ms)),
  async until(fn, ms = 2000) {
    const t0 = Date.now();
    while (Date.now() - t0 < ms) { if (fn()) return true; await new Promise((r) => setTimeout(r, 40)); }
    return false;
  },
  $: (id) => document.getElementById(id),
  text: (id) => (document.getElementById(id)?.textContent ?? "").replace(/\s+/g, " ").trim(),
  calls: (name) => window.__calls.filter((c) => c.rpc === name || c.fn === name),
  lastCall: (name) => window.T.calls(name).at(-1),
  screen: (id) => !document.getElementById(id)?.classList.contains("hidden"),
  show(id) {
    document.querySelectorAll("main").forEach((m) => m.classList.add("hidden"));
    document.getElementById(id)?.classList.remove("hidden");
  },
  /* a minimal child context, so the app boots without a database */
  baseTruth(over = {}) {
    return {
      student: { id: "kid", name: "Atharv", xp: 0, streak: 0, days_in: 1 },
      attempts: { total: 0, last_7: 0, accuracy_7: 0 }, sessions: { last_7: 0, total: 0 },
      content: { total: 0, banks: [] }, families: [], specs: [], tests: { count: 0, last: [], due: null },
      weak: [], tough_topics: [], freshness: [], journey: {}, topup_needed: [], whats_new: {},
      child: {}, accounts: null, papers: [], chat: [], parent_chat: [], progress: null,
      reviews: null, sitting: null, board: null, uploads: [], budget: 150, ...over,
    };
  },
};

/* ---------- the step language the generated scenarios use ----------
   Each step is one string:
     do:startChapter(1)      call an app function
     fill:ans=12             put a value in a field
     click:submitTest        press a real button by its data-action
     expect:screen:session   a screen is visible
     expect:call:submit_answer   a call was made
     expect:text:actionBar~Chapter   some element's text matches
     expect:state:chapter=1  app state
     expect:note~chapter     the last coach note matches
*/
window.__runScenario = async function (spec, T, subs) {
  const fails = [];
  const ok = (m) => fails.push(m);
  for (const raw of spec.steps) {
    const step = String(raw);
    const [kind, rest = ""] = [step.slice(0, step.indexOf(":")), step.slice(step.indexOf(":") + 1)];
    try {
      if (kind === "do") {
        const m = rest.match(/^(\w+)\(([^)]*)\)$/);
        if (!m) { ok("bad step " + step); continue; }
        const args = m[2].split(",").filter((x) => x.trim() !== "").map((x) => {
          const v = x.trim();
          if (subs && Object.prototype.hasOwnProperty.call(subs, v)) return subs[v];
          return /^-?\d+(\.\d+)?$/.test(v) ? Number(v) : v.replace(/^["']|["']$/g, "");
        });
        const fn = window[m[1]];
        if (typeof fn !== "function") { ok("no such function: " + m[1]); continue; }
        await fn(...args);
        await T.wait(spec.wait ?? 120);
      } else if (kind === "fill") {
        const [id, val] = rest.split("=");
        const el = T.$(id);
        if (!el) { ok("no field: " + id); continue; }
        el.value = val;
        el.dispatchEvent(new Event("input", { bubbles: true }));
      } else if (kind === "click") {
        const el = document.querySelector(`[data-action="${rest}"]`);
        if (!el) { ok("no button: " + rest); continue; }
        el.click();
        await T.wait(spec.wait ?? 120);
      } else if (kind === "expect") {
        const [what, arg = ""] = [rest.slice(0, rest.indexOf(":")), rest.slice(rest.indexOf(":") + 1)];
        if (what === "screen" && !T.screen(arg)) ok("screen not shown: " + arg);
        if (what === "call" && T.calls(arg).length === 0) ok("no call: " + arg);
        if (what === "state") {
          const [k, v] = arg.split("=");
          if (String(window.__state[k]) !== v) ok(`state ${k} is ${window.__state[k]}, wanted ${v}`);
        }
        if (what === "text") {
          const [id, want] = arg.split("~");
          const got = T.text(id);
          if (!new RegExp(want).test(got)) ok(`${id} does not match /${want}/`);
        }
        if (what === "note") {
          const note = String(T.calls("coach-chat").at(-1)?.args?.note ?? "");
          if (!new RegExp(arg).test(note)) ok("coach note does not match /" + arg + "/");
        }
      }
    } catch (e) { ok("threw at " + step + ": " + e.message); }
  }
  return fails;
};
