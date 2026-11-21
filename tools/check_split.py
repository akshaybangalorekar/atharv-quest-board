import re, sys, os
root = sys.argv[1]
html = open(os.path.join(root,'index.html'), encoding='utf-8').read()
js = open(os.path.join(root,'assets/app.js'), encoding='utf-8').read()
data = open(os.path.join(root,'assets/data.js'), encoding='utf-8').read()
fails = []
if '<style>' in html: fails.append("css still inline")
if 'type="module">' in html: fails.append("js still inline")
if './assets/app.css' not in html: fails.append("css not linked")
if './assets/app.js' not in html: fails.append("js not linked")
ids = set(re.findall(r'id="([A-Za-z0-9_-]+)"', html))
refs = set(re.findall(r'\$\("([A-Za-z0-9_-]+)"\)', js))
DYNAMIC = {"ans","chk","exNext","exSol","qOpts","qfb","qtimer","qFig","balIn","capCalls","capSpend","capPct","capBelow", "hardExam", "hardWords", "actionBar"}
missing = sorted(refs - ids - DYNAMIC)
if missing: fails.append("elements referenced but missing: " + ", ".join(missing[:12]))
rpcs = set(re.findall(r'sb\.rpc\("([a-z_]+)"', js))
have = set(re.findall(r'export const ([a-z_]+)', data))
miss2 = sorted(r for r in rpcs if r not in have)
if miss2: fails.append("rpc missing from data.js: " + ", ".join(miss2[:12]))
print("FAILURES:" if fails else "ALL CHECKS PASS")
for f in fails: print("  -", f)
