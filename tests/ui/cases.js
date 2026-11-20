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
      assert("the card says nothing is loaded", /nothing loaded/i.test(card));
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
];
