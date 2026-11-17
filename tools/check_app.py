import re, sys, json, subprocess, collections
p = sys.argv[1] if len(sys.argv) > 1 else "/tmp/qb56/index.html"
s = open(p, encoding="utf-8").read()
fails = []

m = re.search(r'<script type="module">(.*?)</script>', s, re.S)
if not m: print("NO MODULE"); sys.exit(1)
js = m.group(1)

# 1. duplicate declarations
for kind, pat in [("function", r'^(?:async )?function ([A-Za-z_$][\w$]*)\s*\('),
                  ("const", r'^const ([A-Za-z_$][\w$]*)\s*='),
                  ("let", r'^let ([A-Za-z_$][\w$]*)\s*=')]:
    names = re.findall(pat, js, re.M)
    dup = {k: v for k, v in collections.Counter(names).items() if v > 1}
    if dup: fails.append(f"duplicate {kind}s: {dup}")

# 2. every handler in the api list is defined
i = js.find("api = {"); j = js.find("} catch", i)
if i > 0 and j > i:
    block = js[i:j]
    names = [x.strip() for x in re.split(r'[,\n]', block.replace("try {", "").replace("api = {", ""))
             if x.strip() and x.strip() not in ("}", ";", "};")]
    defined = set(re.findall(r'^(?:async )?function ([A-Za-z_$][\w$]*)\s*\(', js, re.M))
    missing = [n for n in names if n not in defined]
    if missing: fails.append(f"handlers listed but not defined: {missing}")

# 3. every element the code looks up exists
ids = set(re.findall(r'id="([^"]+)"', s))
refs = set(re.findall(r'\$\("([^"]+)"\)', js))
gone = sorted(refs - ids)
if gone: fails.append(f"elements referenced but missing: {gone}")

# 4. every onclick handler is a real global
handlers = set()
for oc in re.findall(r'onclick="([^"]+)"', s):
    for fn in re.findall(r'([A-Za-z_$][\w$]*)\s*\(', oc):
        if fn not in ("if", "event", "this", "Number", "JSON", "String", "parseInt", "getElementById", "click", "toggle"):
            handlers.add(fn)
defined = set(re.findall(r'^(?:async )?function ([A-Za-z_$][\w$]*)\s*\(', js, re.M))
api_names = set()
i = js.find("api = {"); j = js.find("} catch", i)
if i > 0 and j > i:
    api_names = {x.strip() for x in re.split(r'[,\n]', js[i:j].replace("try {", "").replace("api = {", ""))
                 if x.strip() and x.strip() not in ("}", ";", "};")}
# inline HTML can only call globals, so every handler must be exported
not_exported = sorted(h for h in handlers if h not in api_names and h not in ("alert","confirm","prompt"))
if not_exported: fails.append(f"onclick handlers not reachable from HTML (not exported): {not_exported}")

# 4b. functions called but never defined (the bug that broke the app twice)
BUILTIN = {"if","for","while","switch","catch","return","typeof","Number","String","Boolean","Array","Object",
           "JSON","Math","Date","Promise","Set","Map","parseInt","parseFloat","isNaN","setTimeout","setInterval",
           "clearTimeout","clearInterval","alert","confirm","prompt","fetch","btoa","atob","encodeURIComponent",
           "decodeURIComponent","SpeechSynthesisUtterance","RegExp","Error","console","document","window",
           "SpeechRecognition","webkitSpeechRecognition","DOMParser","Uint8Array","Blob","FileReader","URL",
           "requestAnimationFrame","structuredClone","queueMicrotask","Function","Symbol","BigInt","Intl",
           "addEventListener","removeEventListener","importScripts","rgba","rgb","hsl","var","async","import",
           "onStrand","quality","tick","finish","bumpSilence","url"}
called = set()
for m2 in re.finditer(r'(?<![.\w$])([a-z][A-Za-z0-9_$]*)\s*\(', js):
    called.add(m2.group(1))
defined2 = set(re.findall(r'(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(', js))
consts2 = set(re.findall(r'(?:const|let)\s+([A-Za-z_$][\w$]*)\s*=', js))
unknown_calls = sorted(c for c in called - defined2 - consts2 - BUILTIN)
if unknown_calls: fails.append(f"called but never defined: {unknown_calls}")

# 5. syntax
open("/tmp/_chk.mjs", "w").write(js)
r = subprocess.run(["node", "--check", "/tmp/_chk.mjs"], capture_output=True, text=True)
if r.returncode: fails.append("syntax: " + r.stderr.strip().split("\n")[0])

print("FAILURES:" if fails else "ALL CHECKS PASS")
for f in fails: print("  -", f)
