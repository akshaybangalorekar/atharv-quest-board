#!/usr/bin/env python3
"""tools/release.py — stamp one version everywhere, so a stale cache cannot hide a fix.

    python3 tools/release.py 2.82.0

Does three things, in order:
  1. sets APP_VERSION in assets/app.js (the footer reads it)
  2. points index.html at assets with ?v=<version>, so the browser must fetch the new files
  3. prints what changed, so the push is not a guess
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HTML = ROOT / "index.html"
APP = ROOT / "assets" / "app.js"


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    version = sys.argv[1].strip()

    app = APP.read_text(encoding="utf-8")
    new_app, n1 = re.subn(r'const APP_VERSION = "[0-9.]+";', f'const APP_VERSION = "{version}";', app)
    if n1 != 1:
        print(f"app.js: expected 1 APP_VERSION, found {n1}")
        return 1
    APP.write_text(new_app, encoding="utf-8")

    html = HTML.read_text(encoding="utf-8")
    html = re.sub(r'assets/app\.css(\?v=[0-9.]+)?', f"assets/app.css?v={version}", html)
    html = re.sub(r'assets/app\.js(\?v=[0-9.]+)?', f"assets/app.js?v={version}", html)
    html = re.sub(r'assets/data\.js(\?v=[0-9.]+)?', f"assets/data.js?v={version}", html)
    HTML.write_text(html, encoding="utf-8")

    # the data module is imported from app.js, so its query has to match too
    data_import = re.search(r'from "\./data\.js(\?v=[0-9.]+)?"', new_app)
    if data_import:
        new_app = re.sub(r'from "\./data\.js(\?v=[0-9.]+)?"', f'from "./data.js?v={version}"', new_app)
        APP.write_text(new_app, encoding="utf-8")

    print(f"version {version}")
    print(f"  assets/app.js    APP_VERSION set")
    print(f"  index.html       css and js now ?v={version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
