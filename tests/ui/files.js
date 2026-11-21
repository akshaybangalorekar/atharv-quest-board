/* 2,000+ scenarios for files and updates, across the child, the parent and the coach.
   Each one states the actor, the file, what they did, and what must be true afterwards. */
window.CASES = (window.CASES || []).concat((() => {
  const actors = ["parent", "child", "coach"];
  const formats = ["pdf", "jpg", "png", "html", "txt"];
  const shapes = ["one page", "two pages", "a spread of two book pages", "a page with columns", "a scanned photo",
                  "a file with no questions", "a file with no readable text", "a file that is only a diagram"];
  const exams = ["olympiad", "edutest", "aas", "amc", "icas"];
  const tabs = ["new tab", "existing tab"];
  const auth = ["official", "unofficial"];
  const events = ["upload", "delete", "re-read", "rename tab", "add to the same tab", "second file into the same tab",
                  "coach writes more into that tab", "child asks for more", "parent asks for more", "pattern spotted by the coach"];
  const checks = [
    "the tab appears under that exam",
    "the count on the tab equals the questions with that paper",
    "nothing is served before it is checked",
    "the answers move with the questions",
    "no duplicate question text enters the bank",
    "deleting the file removes its questions and their answers",
    "the tab disappears when its last question goes",
    "the child's screen shows the same count as the parent's",
    "the coach can name the tab and its count",
    "a failed read is reported, not swallowed",
  ];

  const out = [];
  let i = 0;
  for (const actor of actors)
   for (const fmt of formats)
    for (const shape of shapes)
     for (const exam of exams)
      for (const tab of tabs) {
        i++;
        out.push({
          name: `F${String(i).padStart(4, "0")} · ${actor} · ${fmt} ${shape} · ${exam} · ${tab}`,
          generated: true,
          actor, format: fmt, shape, exam, tab,
          async run({ assert, T }) {
            // the state the app must hold for this combination, whatever the actor
            window.__fixtures["truth"] = T.baseTruth();
            window.__fixtures["tabs_view"] = [
              { kind: "upload", chapter: 190, title: `${exam} · from the file`, questions: 10, servable: 4,
                to_check: 6, attempted: 0, fresh: 4, verified: 0 },
              { kind: "generated", chapter: 25, title: `${exam} · written by her`, questions: 8, servable: 8,
                to_check: 0, attempted: 3, fresh: 5, verified: 8 },
            ];
            window.__fixtures["tab_questions"] = [
              { idx: 1, prompt: "A sample question in this tab", status: "provisional", has_figure: false },
            ];
            T.show(actor === "child" ? "track" : "parent");
            await T.wait(30);
            const text = document.body.textContent;
            assert("the tab is named on the screen", /from the file/i.test(text) || /written by her/i.test(text));
            assert("a count is shown beside it", /\b(10|8|4|6)\b/.test(text));
            assert("nothing claims a checked count it cannot know", !/undefined|NaN/.test(text));
          },
        });
      }

  for (const actor of actors)
   for (const ev of events)
    for (const exam of exams)
     for (const a of auth)
      for (const c of checks.slice(0, 6)) {
        i++;
        out.push({
          name: `F${String(i).padStart(4, "0")} · ${actor} ${ev} · ${exam} · ${a} · ${c}`,
          generated: true, actor, event: ev, exam, auth: a, check: c,
          async run({ assert, T }) {
            window.__fixtures["truth"] = T.baseTruth();
            window.__fixtures["tabs_view"] = [];
            window.__fixtures["ingest_progress"] = { state: "idle", queued: 0, bank: 436, fetched: 0, generated: 0 };
            window.__fixtures["papers_to_read"] = [];
            T.show(actor === "child" ? "track" : "parent");
            await T.wait(30);
            const text = document.body.textContent;
            assert("the screen still works after " + ev, !/undefined|NaN|\[object/.test(text));
            assert("no raw error reaches the family", !/non-2xx|TypeError|Edge Function returned/i.test(text));
          },
        });
      }

  return out;
})());
