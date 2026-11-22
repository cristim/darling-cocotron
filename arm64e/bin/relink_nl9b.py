#!/usr/bin/env python3
"""link.py IMG : patch raw arm64e objects (separate paths), link arm64e against the sysroot; if undefined symbols block the
link, record them and relink against a synthetic stub that defines exactly those, so the output (with the unresolved imports
bound to that stub's ordinal) can still be inspected."""
import os, re, shlex, shutil, sys, struct
sys.path.insert(0, "/home/cristi/tmp-opencode/l8-e1/bin")
from l8lib import *
OUT = "/home/cristi/tmp-opencode/notes-l9/l8out"
OV = "/home/cristi/tmp-opencode/notes-l9/overlays"
OVMAP = {"libswiftAppKit.dylib": OV + "/libswiftAppKit.dylib", "libswiftCoreGraphics.dylib": OV + "/libswiftCoreGraphics.dylib"}
NOMAP = bool(os.environ.get("NL9_NOMAP"))
os.makedirs(OUT + "/obj/" + sys.argv[1], exist_ok=True); os.makedirs(OUT + "/lib2", exist_ok=True)

img = sys.argv[1]
EXCL = sys.argv[2:]
G = R + "/guest"
COMP = sysfile("/usr/lib/darling/libCocotronFoundationPrivate.dylib")
a = shlex.split(open("%s/cmds/%s.link" % (R, img)).read().strip().lstrip(": &").replace("&& ", ""))
outn = a[a.index("-o") + 1]
inst, compat_p, cur_p = plain_id(B + "/" + outn)
od = "%s/rawobj/%s" % (OUT, img)
objs = [x for x in a if x.endswith(".o") and x.startswith("src/") and not any(e in x for e in EXCL)]
objs += [x for x in open(OUT + "/newobjs-" + img + ".txt").read().split() if x not in objs]
patched = []
for o in objs:
    raw = os.path.join(od, o.replace("/", "__") + ".raw")
    if not os.path.exists(raw):
        print("LINK-SKIPPED: object not compiled:", o); sys.exit(3)
    p = os.path.join(OUT, "obj", img, os.path.basename(raw)[:-4] + ".patched.o")
    data = open(raw, "rb").read()
    sub = struct.unpack_from("<I", data, 8)[0]
    if sub & 0xFF000000:
        recipe.patch_file(raw, p)
    else:
        open(p, "wb").write(data)
    patched.append(p)

notes = []
def mapdep(p):
    full = p if p.startswith("/") else B + "/" + p
    if "/src/external/swift/" in full and os.path.basename(full) in OVMAP and not NOMAP:
        notes.append("mapped to overlay copy: " + OVMAP[os.path.basename(full)]); return OVMAP[os.path.basename(full)]
    i = plain_id(full)
    if not i:
        notes.append("not a Mach-O, ignored (as in the plain build): " + p); return None
    if not os.path.exists(sysfile(i[0])):
        notes.append("no sysroot file for %s (%s)" % (i[0], p)); return None
    return sysfile(i[0])

def build_cmd(extra_libs=()):
    late = []
    l = [LD, "-arch", "arm64e", "-fixup_chains", "-platform_version", "macos", "11.0", "11.0", "-dylib", "-Z",
         "-syslibroot", SYSROOT]
    for x in a:
        if x.startswith("-Wl,"):
            p = x[4:].split(",")
            if p[0] in ("-dylib_file", "-Z", "-sdk_version", "-rpath-link"): continue
            if p[0] == "-dylib_install_name": p[0] = "-install_name"
            if p[0] == "-reexport_library":
                m = mapdep(p[1])
                if m and "CoreVideo" in m and os.environ.get('L8_FIRST'): late.append(m)
                elif m: l += ["-reexport_library", m]
                continue
            l += p
    l += patched
    if os.environ.get('L8_FIRST'): l += [sysfile(os.environ['L8_FIRST'])] + late
    for x in a:
        if x.startswith("src/") and x != outn and not x.endswith(".o"):
            m = mapdep(x)
            if m: l.append(m)
    l += [COMP] + list(extra_libs)
    l += os.environ.get("L8_LDEXTRA", "").split()
    l += ["-o", "%s/lib2/%s.dylib" % (OUT, img)]
    return l

def run(l, tag):
    open("%s/logs/t4a-relink-%s.%s.cmd" % (OUT, img, tag), "w").write(" ".join(shlex.quote(x) for x in l) + "\n")
    r = sh(l)
    open("%s/logs/t4a-relink-%s.%s.log" % (OUT, img, tag), "w").write(r.stdout + r.stderr)
    return r

r = run(build_cmd(), "1")
unresolved = []
if r.returncode == 0:
    status = "linked, 0 unresolved"
else:
    txt = r.stdout + r.stderr
    unresolved = sorted(set(re.findall(r'^\s+"([^"]+)", referenced from', txt, re.M)))
    other = [l for l in txt.splitlines() if l.startswith("ld: ") and "symbol(s) not found" not in l and "Undefined symbols" not in l]
    if not unresolved:
        status = "LINK FAILED (no undefined-symbol list): " + " | ".join(other)[:600]
        print(img, status); open("%s/logs/t4a-relink-%s.status" % (OUT, img), "w").write(status + "\n"); sys.exit(1)
    open("%s/logs/t4a-unresolved-%s.txt" % (OUT, img), "w").write("\n".join(unresolved) + "\n")
    status = "LINK FAILED: %d unresolved symbols (NL9 copy fails loud, no stub): %s" % (len(unresolved), unresolved[:20])
    print(img, status); open("%s/logs/t4a-status-%s.txt" % (OUT, img), "w").write(status + "\n"); sys.exit(1)
open("%s/logs/t4a-relink-%s.status" % (OUT, img), "w").write(status + "\n" + "\n".join(notes) + "\n" + "\n".join(unresolved) + "\n")
print(img, status, "| notes:", len(notes), "| unresolved:", unresolved)
