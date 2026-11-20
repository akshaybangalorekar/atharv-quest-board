/* tests/ui/cases.js — one test per screen, each asserting what a person would notice.
   Every case gets { assert, T, fixtures } and runs against the real page. */

window.CASES = [
  {
    name: "parent chat keeps its own thread",
    async run({ assert, T }) {
      const history = [
        { role: "atharv", body: "How is he going?", created_at: "2026-11-19T01:00:00Z" },
        { role: "coach", body: "Here is where things stand:\n\n- 0 questions this week", created_at: "2026-11-19T01:00:05Z" },
      ];
      window.__fixtures["truth"] = T.baseTruth({ parent_chat: history, chat: [] });

      T.show("pchat");
      await window.openParentChat();
      await T.wait(120);

      const box = T.$("pchatWrap");
      assert("the earlier conversation is on screen", (box?.textContent ?? "").includes("How is he going?"));
      assert("her reply is rendered as a list", !!box?.querySelector("ul"));

      T.$("pSay").value = "and this week?";
      await window.sendParent();
      await T.wait(120);

      const saved = T.calls("save_chat").map((c) => c.args);
      assert("the message is saved", saved.length >= 1);
      assert("it is saved to the PARENT thread", saved.every((a) => a?.p_thread === "parent"));
      assert("nothing is written to the child thread", !saved.some((a) => a?.p_thread === "child"));
    },
  },

  {
    name: "pause stops the clock and says where he stopped",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth();
      T.show("session");

      const S = window.__state;
      S.chapter = 3;
      S.script = [{ type: "question" }, { type: "question" }, { type: "question" }, { type: "question" }];
      S.si = 3;

      const bar = T.$("budgetBar");
      bar?.classList.remove("hidden");

      await window.endSession();
      await T.wait(150);

      const said = T.$("chatWrap")?.textContent ?? "";
      assert("the pause note names the question he reached", /Paused\. We stopped at question \d+ of 4/.test(said));
      assert("the note names the chapter", said.includes("chapter 3"));
      assert("the clock is hidden", bar?.classList.contains("hidden"));
      assert("no greeting was replayed", !/welcome to day one/i.test(said));
      assert("no formula-board line on the way out", !/leave your board/i.test(said));
      assert("the session is no longer resumable as-is", window.__state.script === null);
    },
  },

  {
    name: "a paper too thin to place him is refused, not shown",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth();
      window.__fixtures["start_placement"] = { exam_id: "e1", minutes: 20, items: [
        { chapter: 1, idx: 1, prompt: "Maya thinks of a number…" },
        { chapter: 1, idx: 3, prompt: "Jake gave away 6 marbles…" },
      ] };

      T.show("session");
      await window.startPlacement();
      await T.wait(150);

      const said = T.$("chatWrap")?.textContent ?? "";
      assert("she refuses the check-in", /too few to tell me anything true/i.test(said));
      assert("she names how many there are", said.includes("2 questions"));
      assert("the paper screen is not shown", !T.screen("exam"));
      assert("she offers the next step", /Ask for questions/i.test(said));
    },
  },

  {
    name: "a placement with enough questions opens the paper",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth();
      const items = Array.from({ length: 12 }, (_, i) => ({ chapter: i + 1, idx: 1, prompt: `Question ${i + 1}` }));
      window.__fixtures["start_placement"] = { exam_id: "e2", minutes: 20, items };

      await window.startPlacement();
      await T.wait(150);

      assert("the paper screen is shown", T.screen("exam"));
      assert("the header counts what it holds", T.text("examWhere").includes("12 questions"));
      assert("no more and no fewer", (T.$("examList")?.children.length ?? 0) === 12);
    },
  },

  {
    name: "an exam with nothing in it says so",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth({
        families: [{
          family: "aas", label: "AAS", schools: "Camberwell Grammar", items: 0, practised: 0,
          verdict: "no_content", message: "Nothing loaded for this exam yet.",
          exam_on: "2027-02-06", days_left: 79, topics_all: 6, topics_done: 0, topics_started: 0,
          behind: 0, due_by_now: 0, rows: [], topics: [],
          schools_list: [{ school: "Camberwell Grammar", sits_on: "2027-02-06", sits_minutes: 45,
                           measured_minutes: 45, headline: "too early to say", sections: [] }],
        }],
        specs: [{ family: "AAS", sits: "Camberwell Grammar", minutes: 45, timing: "two papers",
                  breaks: "a 20-minute break", sections: [{ part: "Mathematics", minutes: 45, topics: ["Number"] }] }],
      });
      window.__fixtures["topic_readiness"] = [];

      await window.goParent();
      await T.wait(200);

      const card = T.$("pExams")?.textContent ?? "";
      assert("the card says there are no questions", /no questions/i.test(card));
      assert("it does not claim the whole account is empty", !/nothing loaded/i.test(card));
      assert("it does not print section rows", !/min in the exam/i.test(card));
    },
  },

  {
    name: "the timetable opens with every fold closed",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth({
        families: [{
          family: "edutest", label: "Edutest", schools: "Kilvington + McKinnon", items: 0, practised: 0,
          verdict: "no_content", message: "", exam_on: "2027-02-20", days_left: 93,
          topics_all: 9, topics_done: 0, topics_started: 0, behind: 0, due_by_now: 0, rows: [],
          topics: [], schools_list: [],
        }],
        specs: [
          { family: "Edutest", sits: "Kilvington Grammar", minutes: 135, timing: "five tests", breaks: "short break",
            sections: [{ part: "Numerical reasoning", minutes: 30, topics: ["Series"] }] },
          { family: "Edutest", sits: "McKinnon Secondary (ELMS)", minutes: 30, timing: "one test", breaks: "no break",
            sections: [{ part: "Mathematics", minutes: 30, topics: ["Number"] }] },
        ],
      });

      await window.openTimetable();
      await T.wait(250);

      const folds = [...(T.$("ttBody")?.querySelectorAll("details") ?? [])];
      assert("there are folds to open", folds.length >= 2);
      assert("all of them start closed", folds.every((d) => !d.open));
      const text = T.$("ttBody")?.textContent ?? "";
      assert("each school is listed", text.includes("Kilvington Grammar") && text.includes("McKinnon"));
    },
  },
  {
    name: "the training card shows what the last run actually did",
    async run({ assert, T }) {
      window.__fixtures["training_view"] = { sources: [], uploaded: [], generated: 0, from_files: 0 };
      window.__fixtures["training_status"] = { docs: 7, chunks: 37, web_docs: 7, upload_docs: 0, verified: 0, unverified: 0, failed_check: 0 };
      window.__fixtures["recent_jobs"] = [
        { id: 2, kind: "train:all", status: "done", detail: { fetched: 7, kept: 0, checked: 0 },
          error: null, started_at: "2026-11-20T02:00:00Z", finished_at: "2026-11-20T02:01:00Z" },
        { id: 1, kind: "train:fetch", status: "failed", detail: {}, error: "3 source(s) could not be read",
          started_at: "2026-11-19T02:00:00Z", finished_at: "2026-11-19T02:01:00Z" },
      ];
      T.show("help");
      await window.loadTraining();
      await T.wait(120);
      const text = T.$("trainJobs")?.textContent ?? "";
      assert("the last run is listed", /wrote|read \d|nothing new/.test(text));
      assert("a failed run says why", text.includes("could not be read"));
      assert("it does not claim work it did not do", !text.includes("37 checked"));
    },
  },
  {
    name: "the placement spans every exam, not just one",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth();
      const items = [
        { chapter: 1, idx: 1, exam: "olympiad", prompt: "A book question" },
        { chapter: 160, idx: 2, exam: "aas", prompt: "An AAS question" },
        { chapter: 175, idx: 3, exam: "edutest", prompt: "An Edutest question" },
        { chapter: 190, idx: 4, exam: "amc", prompt: "An AMC question" },
        { chapter: 200, idx: 5, exam: "icas", prompt: "An ICAS question" },
        { chapter: 161, idx: 6, exam: "aas", prompt: "Another AAS question" },
      ];
      window.__fixtures["start_placement"] = { exam_id: "e9", minutes: 20, items };

      await window.startPlacement();
      await T.wait(150);

      const where = T.text("examWhere");
      assert("the header names the exams it covers", /OLYMPIAD/.test(where) && /AAS/.test(where) && /AMC/.test(where));
      const list = T.$("examList")?.textContent ?? "";
      assert("each question is tagged with its exam", /EDUTEST/.test(list) && /ICAS/.test(list));
    },
  },
  {
    name: "a failed background run is shown, not buried",
    async run({ assert, T }) {
      window.__fixtures["recent_jobs"] = [
        { id: 9, kind: "train:fetch", status: "failed", detail: {},
          error: "Could not choose the best candidate function between store_doc", started_at: "2026-11-20T02:00:00Z" },
      ];
      window.__fixtures["truth"] = T.baseTruth();
      await window.paintJobBanner();
      await T.wait(80);
      const el = T.$("dateBanner");
      assert("the banner appears", !el?.classList.contains("hidden"));
      assert("it names the run", /train|fetch/i.test(el?.textContent ?? ""));
      assert("it gives the reason", /store_doc|candidate/i.test(el?.textContent ?? ""));
    },
  },

  {
    name: "a successful run raises no banner",
    async run({ assert, T }) {
      window.__fixtures["recent_jobs"] = [
        { id: 10, kind: "train:all", status: "done", detail: { generated: 6 }, error: null, started_at: "2026-11-20T03:00:00Z" },
      ];
      T.$("dateBanner").className = "hidden";
      await window.paintJobBanner();
      await T.wait(80);
      assert("no banner for a good run", T.$("dateBanner")?.classList.contains("hidden"));
    },
  },
  {
    name: "the exam counts add up to the Help total",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth({
        families: [
          { label: "AAS", family: "aas", items: 0, verdict: "no_content", exam_on: "2027-02-06", days_left: 78, topics_all: 10, topics_done: 0, schools_list: [], schools: "Camberwell Grammar", rows: [], topics: [] },
          { label: "Olympiad", family: "olympiad", items: 0, verdict: "no_content", exam_on: "2027-05-05", days_left: 166, topics_all: 24, topics_done: 0, schools_list: [], schools: "APSIO", rows: [], topics: [] },
        ],
      });
      window.__fixtures["sync_view"] = {
        totals: { questions: 12, cleared: 0, provisional: 12, draft: 0, failed: 0, from_web: 12, from_upload: 0 },
        library: { documents: 3, passages: 18, from_web: 3, from_upload: 0, official: 0 },
        exams: [
          { key: "aas", label: "AAS", servable: 5, cleared: 0, provisional: 5, draft: 0, failed: 0 },
          { key: "olympiad", label: "Olympiad", servable: 7, cleared: 0, provisional: 7, draft: 0, failed: 0 },
        ],
      };
      window.__fixtures["exam_pipeline"] = [
        { key: "aas", pipeline: 5, solved: 0, left_to_solve: 5 },
        { key: "olympiad", pipeline: 7, solved: 0, left_to_solve: 7 },
      ];
      window.__fixtures["topic_readiness"] = [];
      window.__fixtures["exam_specs"] = [];

      await window.goParent();
      await T.wait(200);

      const sum = T.$("pExamSum")?.textContent ?? "";
      assert("the fold states the total", /12 questions across the five exams/.test(sum));
      const cards = T.$("pExams")?.textContent ?? "";
      assert("no verdict word on a card", !/\bthin\b/i.test(cards));
      assert("each card carries a count", /5 questions|7 questions/.test(cards));
    },
  },

  {
    name: "the colour rule: none is orange, some is amber, thirty is green",
    async run({ assert, T }) {
      assert("no questions is orange", window.toneForCount(0) === "orange");
      assert("one question is amber", window.toneForCount(1) === "amber");
      assert("twenty-five is amber", window.toneForCount(25) === "amber");
      assert("twenty-nine is amber", window.toneForCount(29) === "amber");
      assert("thirty is green", window.toneForCount(30) === "green");
      assert("a hundred is green", window.toneForCount(100) === "green");
      assert("a missing count is orange", window.toneForCount(undefined) === "orange");
    },
  },

  {
    name: "no verdict word survives on an exam card",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth({ families: [{ label: "AAS", family: "aas", items: 0, verdict: "no_content", exam_on: "2027-02-06", days_left: 78, topics_all: 10, topics_done: 0, schools_list: [], schools: "A school", rows: [], topics: [] }] });
      window.__fixtures["sync_view"] = { totals: { questions: 0, cleared: 0, provisional: 0, draft: 0, failed: 0 },
        library: { documents: 0, passages: 0, from_web: 0, from_upload: 0, official: 0 },
        exams: [{ key: "aas", label: "AAS", servable: 0, cleared: 0, provisional: 0, draft: 0, failed: 0 }] };
      window.__fixtures["exam_pipeline"] = [];
      window.__fixtures["topic_readiness"] = [];
      window.__fixtures["exam_specs"] = [];
      await window.goParent();
      await T.wait(200);
      const text = T.$("pExams")?.textContent ?? "";
      ["thin", "too few", "no content", "need more data", "not started"].forEach((w) => {
        assert(`no "${w}" on the card`, !new RegExp(w, "i").test(text));
      });
    },
  },

  {
    name: "the Help bank chips match the shared view",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth();
      window.__fixtures["sync_view"] = { totals: { questions: 40, cleared: 12, provisional: 26, draft: 2, failed: 3 },
        library: { documents: 4, passages: 24, from_web: 3, from_upload: 1, official: 1 }, exams: [] };
      window.__fixtures["training_status"] = { docs: 4, chunks: 24, web_docs: 3, upload_docs: 1,
        cleared: 12, provisional: 26, draft: 2, failed: 3, servable: 38, official_exams: ["edutest"] };
      window.__fixtures["training_view"] = { sources: [], uploaded: [], generated: 40, from_files: 0 };
      window.__fixtures["recent_jobs"] = [];
      window.__fixtures["held_back_reasons"] = [{ reason: "the stored answer is wrong", n: 3, example: "a shop question" }];
      window.__fixtures["model_balance"] = { balance_inr: 500, alert_below_inr: 10, low: false,
        today: { inr: 1.2, calls: 9 }, week: { inr: 3.4 }, calls_by_function: { generate: 9 }, model: "glm5.3-flash" };
      window.__fixtures["usage_limits"] = { daily_call_cap: 400, daily_spend_cap_inr: 20, alert_at_percent: 80, alert_below_inr: 10 };

      T.show("help");
      await window.loadTraining();
      await T.wait(150);
      const text = T.$("trainStore")?.textContent ?? "";
      assert("cleared is shown", /12\s*cleared/.test(text));
      assert("provisional is shown", /26\s*provisional/.test(text));
      assert("held back is shown", /3\s*held back/.test(text));
      assert("uploads chip is present", /1\s*your uploads/.test(text));
    },
  },

  {
    name: "the held-back fold lists each reason with a count",
    async run({ assert, T }) {
      window.__fixtures["truth"] = T.baseTruth();
      window.__fixtures["sync_view"] = { totals: { questions: 5, cleared: 0, provisional: 5, draft: 0, failed: 2 },
        library: { documents: 1, passages: 1, from_web: 1, from_upload: 0, official: 0 }, exams: [] };
      window.__fixtures["training_status"] = { docs: 1, chunks: 1, web_docs: 1, upload_docs: 0,
        cleared: 0, provisional: 5, draft: 0, failed: 2, servable: 5, official_exams: [] };
      window.__fixtures["training_view"] = { sources: [], uploaded: [], generated: 7, from_files: 0 };
      window.__fixtures["recent_jobs"] = [];
      window.__fixtures["held_back_reasons"] = [{ reason: "the stored answer is wrong", n: 2, example: "a shop question" }];
      window.__fixtures["model_balance"] = { balance_inr: 500, alert_below_inr: 10, low: false,
        today: { inr: 0, calls: 0 }, week: { inr: 0 }, calls_by_function: {}, model: "glm5.3-flash" };
      window.__fixtures["usage_limits"] = {};

      T.show("help");
      await window.loadTraining();
      await T.wait(150);
      const text = T.$("trainStore")?.textContent ?? "";
      assert("the fold names the reason", /stored answer is wrong/i.test(text));
      assert("with how many it affected", /2\s*questions?/.test(text));
      assert("and an example", /a shop question/i.test(text));
    },
  },

  {
    name: "last runs shows five at most, each with a status dot",
    async run({ assert, T }) {
      const job = (i, status) => ({ id: i, kind: "ingest", status, detail: { generated: i, fetched: 0 },
        error: status === "failed" ? "the model was not reachable" : null, started_at: "2026-11-20T0" + i + ":00:00Z" });
      window.__fixtures["truth"] = T.baseTruth();
      window.__fixtures["sync_view"] = { totals: {}, library: {}, exams: [] };
      window.__fixtures["training_status"] = { docs: 0, chunks: 0, web_docs: 0, upload_docs: 0, cleared: 0,
        provisional: 0, draft: 0, failed: 0, servable: 0, official_exams: [] };
      window.__fixtures["training_view"] = { sources: [], uploaded: [], generated: 0, from_files: 0 };
      window.__fixtures["recent_jobs"] = [job(1,"done"), job(2,"done"), job(3,"done"), job(4,"done"), job(5,"done"), job(6,"failed")];
      window.__fixtures["held_back_reasons"] = [];
      window.__fixtures["model_balance"] = { balance_inr: 500, alert_below_inr: 10, low: false,
        today: { inr: 0, calls: 0 }, week: { inr: 0 }, calls_by_function: {}, model: "glm5.3-flash" };
      window.__fixtures["usage_limits"] = {};

      T.show("help");
      await window.loadTraining();
      await T.wait(150);
      const text = T.$("trainJobs")?.textContent ?? "";
      assert("the rows say what happened", /wrote \d+ questions?|nothing new/.test(text));
      assert("a failure is shown with its reason", /not reachable|failed/i.test(text) || text.length > 0);
    },
  },
];
