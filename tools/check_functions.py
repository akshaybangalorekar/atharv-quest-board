#!/usr/bin/env python3
"""tools/check_functions.py — the class of bug that cost us a week of silent zeros.

Written after `fillFromMaterial` was called without being imported: the function threw
ReferenceError, a try/catch swallowed it, the job said "done", and the bank stayed at zero.
A page of tests could not have caught it, because the page never runs that code.

What this checks, for every edge function in supabase/functions/:
  1. every name imported from _shared is exported by that _shared file
  2. every _shared helper that is *used* in a function is also *imported* by it
  3. no try/catch swallows an error into a bare `catch (_) {}` without recording it somewhere
  4. every function the app calls from the browser (functions.invoke) exists on disk

    python3 tools/check_functions.py [repo root]
"""
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
FN = os.path.join(ROOT, "supabase", "functions")
SHARED = os.path.join(FN, "_shared")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def exported(shared_dir):
    names = {}
    for file in os.listdir(shared_dir):
        if not file.endswith(".ts"):
            continue
        text = read(os.path.join(shared_dir, file))
        names[file] = set(re.findall(r"export\s+(?:async\s+)?(?:function|const|let|type)\s+([A-Za-z_$][\w$]*)", text))
    return names


def main():
    if not os.path.isdir(FN):
        print("no supabase/functions directory — nothing to check")
        return 0

    shared = exported(SHARED)
    all_shared = set().union(*shared.values()) if shared else set()
    fails = []
    checked = 0

    for entry in sorted(os.listdir(FN)):
        folder = os.path.join(FN, entry)
        index = os.path.join(folder, "index.ts")
        if entry.startswith("_") or not os.path.isfile(index):
            continue
        checked += 1
        text = read(index)

        # 1 and 2: what it imports, and what it uses
        imported = set()
        for m in re.finditer(r'import\s*\{([^}]*)\}\s*from\s*"\./_shared/([\w.]+)\.ts"', text):
            names = {n.strip().split(" as ")[0].strip() for n in m.group(1).split(",") if n.strip()}
            source = m.group(2) + ".ts"
            for n in names:
                if source in shared and n not in shared[source]:
                    fails.append(f"{entry}: imports {n} from _shared/{source}, which does not export it")
            imported |= names

        used = {n for n in all_shared if re.search(rf"(?<![\w$.]){re.escape(n)}\s*\(", text)}
        missing = sorted(used - imported)
        if missing:
            fails.append(f"{entry}: uses {', '.join(missing)} without importing it — ReferenceError at runtime")

        # 3: a swallowed error with no record is how a zero looks like a success
        for m in re.finditer(r"catch\s*\([^)]*\)\s*\{\s*(?:/\*[^*]*\*/\s*)?\}", text):
            line = text[: m.start()].count("\n") + 1
            fails.append(f"{entry}:{line}: empty catch — an error there becomes a silent zero")

    # 4: everything the browser calls must exist
    app = os.path.join(ROOT, "assets", "app.js")
    if os.path.isfile(app):
        for name in sorted(set(re.findall(r'functions\.invoke\("([\w-]+)"', read(app)))):
            if not os.path.isfile(os.path.join(FN, name, "index.ts")):
                fails.append(f"the app calls {name}(), which has no function on disk")

    print(f"checked {checked} edge functions")
    if fails:
        print("FAILURES:")
        for f in fails:
            print("  -", f)
        return 1
    print("ALL CHECKS PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
