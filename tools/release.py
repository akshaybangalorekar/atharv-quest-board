import re, sys
from pathlib import Path
v = sys.argv[1]
root = Path(".")
html = (root/"index.html").read_text(encoding="utf-8")
app = (root/"assets"/"app.js").read_text(encoding="utf-8")
app = re.sub(r'const APP_VERSION = "[0-9.]+";', f'const APP_VERSION = "{v}";', app)
html = re.sub(r'assets/app\.css(\?v=[0-9.]+)?', f"assets/app.css?v={v}", html)
html = re.sub(r'assets/app\.js(\?v=[0-9.]+)?', f"assets/app.js?v={v}", html)
app = re.sub(r'from "\./data\.js(\?v=[0-9.]+)?"', f'from "./data.js?v={v}"', app)
(root/"index.html").write_text(html, encoding="utf-8")
(root/"assets"/"app.js").write_text(app, encoding="utf-8")
print("version", v)
