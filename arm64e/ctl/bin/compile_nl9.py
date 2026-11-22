#!/usr/bin/env python3
"""NL9: recompile every object of IMG (link-line objects plus sources new on the T4a branch) as arm64e from the T4a worktree.
Raws go to NL9/l8out/rawobj/IMG; nothing is written into l8-e1 or the guest-build tree. Usage: compile_nl9.py WORKTREE IMG..."""
import json, os, shlex, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
N = "/home/cristi/tmp-opencode/cocotron-kept/arm64e/ctl"
R = "/home/cristi/tmp-opencode/l8-e1"
OLD = "/home/cristi/tmp-opencode/darling-guest-build/src/darling-super/src/external/cocotron"
FWOLD = "/home/cristi/tmp-opencode/darling-guest-build/src/darling-super/framework-include"
WT = sys.argv[1].rstrip("/")
db = json.load(open("/home/cristi/tmp-opencode/claude-1000/-home-cristi/4c2e5d58-cc50-4d3a-8f75-23c5ccb2157c/scratchpad/arm64e-spike/compdb.json"))
by = {}
for e in db: by.setdefault(e["output"], e)

def newsrc(img):
    comp = img.split("_")[-1]
    r = subprocess.run(["git", "-C", WT, "diff", "--name-status", "e2219b02", "HEAD", "--", comp], capture_output=True, text=True).stdout
    cm = open("%s/%s/CMakeLists.txt" % (WT, comp)).read()
    out = []
    for l in r.splitlines():
        st, p = l.split("\t")[:2]
        if st == "A" and p.endswith((".m", ".c")) and "/include/" not in p and "/tests/" not in p:
            rel = p[len(comp) + 1:]
            if rel in cm or os.path.basename(rel) in cm:
                out.append(rel)
    return comp, out

def one(img, o, out):
    name = o.replace("/", "__")
    raw = os.path.join(out, name + ".raw")
    if o in by:
        e = by[o]
        cmd = e["command"]
    else:
        e = by[TEMPL[img]]
        comp = img.split("_")[-1]
        rel = o.split(".dir/")[1][:-2]
        cmd = e["command"].replace(e["file"], "%s/%s/%s" % (OLD, comp, rel)).replace(TEMPL[img], o)
    cmd = cmd.replace(FWOLD, N + "/fwinc").replace(OLD, WT)
    args = shlex.split(cmd); new = []; i = 0
    while i < len(args):
        x = args[i]
        if x == "-target" and args[i+1].startswith("aarch64-apple-darwin"):
            new += ["-target", "arm64e-" + args[i+1].split("-", 1)[1]]; i += 2; continue
        if x == "-arch" and args[i+1] == "arm64": i += 2; continue
        if x == "-o": new += ["-o", raw]; i += 2; continue
        if x in ("-MD",): i += 1; continue
        if x in ("-MF", "-MT"): i += 2; continue
        new.append(x); i += 1
    r = subprocess.run(new, cwd=e["directory"], capture_output=True, text=True)
    open(os.path.join(out, name + ".log"), "w").write(r.stdout + r.stderr)
    print(("OK   " if r.returncode == 0 else "FAIL ") + o, flush=True)
    return o, r.returncode

TEMPL = {}
for img in sys.argv[2:]:
    a = shlex.split(open("%s/cmds/%s.link" % (R, img)).read().strip().lstrip(": &").replace("&& ", ""))
    objs = [x for x in a if x.endswith(".o") and x.startswith("src/")]
    comp, ns = newsrc(img)
    TEMPL[img] = next(o for o in objs if o.endswith(".m.o") and o in by)
    new = ["src/external/cocotron/%s/CMakeFiles/%s.dir/%s.o" % (comp, comp, r) for r in ns]
    new = [n for n in new if n not in objs]
    out = "%s/l8out/rawobj/%s" % (N, img); os.makedirs(out, exist_ok=True)
    open("%s/l8out/newobjs-%s.txt" % (N, img), "w").write("\n".join(new) + "\n")
    print(img, "link-line objects", len(objs), "new", len(new), new, flush=True)
    todo = objs + new
    with ThreadPoolExecutor(1) as ex: res = list(ex.map(lambda o: one(img, o, out), todo))
    ok = sum(1 for _, c in res if c == 0)
    print("%s: %d/%d compiled" % (img, ok, len(res)), flush=True)
