#!/usr/bin/env python3
"""NL9: build NL9/fwinc = copy of darling-super/framework-include with symlinks that resolve into the guest-build cocotron retargeted to the T4a worktree. Read-only on the sources."""
import os, sys
SRC = "/home/cristi/tmp-opencode/darling-guest-build/src/darling-super/framework-include"
OLD = "/home/cristi/tmp-opencode/darling-guest-build/src/darling-super/src/external/cocotron"
NEW = sys.argv[1]
OUT = "/home/cristi/tmp-opencode/notes-l9/fwinc"
os.makedirs(OUT, exist_ok=True)
n = 0
for e in sorted(os.listdir(SRC)):
    t = os.path.realpath(os.path.join(SRC, e))
    if t.startswith(OLD + "/"):
        t = NEW + t[len(OLD):]; n += 1
    d = os.path.join(OUT, e)
    if os.path.lexists(d): os.remove(d)
    os.symlink(t, d)
print("retargeted", n, "of", len(os.listdir(SRC)))
