import re, sys, os
root = sys.argv[1]
html = open(os.path.join(root,'index.html'), encoding='utf-8').read()
js = open(os.path.join(root,'assets/app.js'), encoding='utf-8').read()
fails = []
if 'onclick=' in html: fails.append("inline onclick left in html")
if 'onclick=' in js: fails.append("inline onclick left in js")
named = set(re.findall(r'data-action="([A-Za-z_$][\w$]*)"', html + js))
block = js[js.find("registerActions({"): js.find("\n});", js.find("registerActions({"))]
wired = set(re.findall(r'^\s{2}([A-Za-z_$][\w$]*):', block, re.M))
missing = sorted(named - wired)
if missing: fails.append("actions with no handler: " + ", ".join(missing))
print(f"{len(named)} actions named, {len(wired)} wired")
print("FAILURES:" if fails else "ALL CHECKS PASS")
for f in fails: print("  -", f)
