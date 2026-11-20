#!/usr/bin/env python3
"""tests/ui/run.py — run the per-screen tests in a real browser.

Each case gets a fresh copy of index.html with the stub and the case list injected, is run
headlessly, and reports PASS/FAIL line by line. Exit code is non-zero if anything fails.

    python3 tests/ui/run.py            # all cases
    python3 tests/ui/run.py pause      # only cases whose name contains "pause"
"""
import json, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HTML = os.path.join(ROOT, "index.html")
ASSETS = os.path.join(ROOT, "assets")
UI = os.path.join(ROOT, "tests", "ui")

RUNNER = """
<script>
window.__results = [];
window.__done = false;
(async function () {
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  await wait(1200);
  const only = %FILTER%;
  for (const c of (window.CASES || [])) {
    if (only && !c.name.toLowerCase().includes(only)) continue;
    const checks = [];
    const assert = (what, ok) => checks.push({ what, ok: !!ok });
    try {
      await c.run({ assert, T: window.T });
    } catch (e) {
      checks.push({ what: "the case threw: " + (e && e.message ? e.message : e), ok: false });
    }
    window.__results.push({ name: c.name, checks });
  }
  window.__done = true;
  const d = document.createElement("div");
  d.id = "testout";
  d.textContent = JSON.stringify(window.__results);
  document.body.appendChild(d);
})();
</script>
"""


def build(filter_name: str, out_path: str) -> None:
    html = open(HTML, encoding="utf-8").read()
    inject = (
        '<script src="./tests/ui/harness.js"></script>'
        '<script src="./tests/ui/cases.js"></script>'
    )
    # the stub has to exist before the app creates its client
    html = html.replace('<script src="./supabase.js"></script>',
                        '<script src="./supabase.js"></script>' + inject, 1)
    runner = RUNNER.replace("%FILTER%", json.dumps(filter_name))
    head, sep, tail = html.rpartition("</body>")
    html = head + runner + sep + tail
    open(out_path, "w", encoding="utf-8").write(html)


def run_case(page: str) -> list:
    cmd = [
        "chromium", "--headless=new", "--no-sandbox", "--disable-gpu",
        "--allow-file-access-from-files", "--window-size=1100,800",
        "--virtual-time-budget=25000", "--dump-dom", "file://" + page,
    ]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=120).stdout
    m = re.search(r'id="testout">(.*?)</div>', out, re.S)
    if not m:
        return [{"name": "the page never finished", "checks": [{"what": "no result marker", "ok": False}]}]
    return json.loads(m.group(1))


def main() -> int:
    only = (sys.argv[1] if len(sys.argv) > 1 else "").lower()
    with tempfile.TemporaryDirectory() as tmp:
        # the page loads ./assets and ./tests relative to its own folder
        page = os.path.join(ROOT, ".uitest.html")
        build(only, page)
        try:
            results = run_case(page)
        finally:
            os.path.exists(page) and os.remove(page)

    passed = failed = 0
    for case in results:
        ok = all(c["ok"] for c in case["checks"])
        print(("PASS  " if ok else "FAIL  ") + case["name"])
        for c in case["checks"]:
            if not c["ok"]:
                print("        ✗ " + c["what"])
        passed += ok
        failed += (not ok)

    print(f"\n{passed} passed, {failed} failed, {len(results)} cases")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
