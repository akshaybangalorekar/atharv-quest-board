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
