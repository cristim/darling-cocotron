#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Checks that NSWindow keeps collectionBehavior and tabbingMode per window. Runs the real accessors of
# AppKit/NSWindow.m on the host in a mock NSWindow (no Foundation, no display). Wherever the two variables are
# declared (the NSWindow @interface ivar block in NSWindow.h, or the top of @implementation NSWindow in
# NSWindow.m), those declarations are cut out at test time and placed where they were.
# Usage: tests/nswindow-window-state-host.sh [OBJC_PREFIX]
#   OBJC_PREFIX holds include/objc/runtime.h and lib/libobjc for a GNUstep-ABI runtime (libobjc2); without it the
#   compiler's default search paths are used. Environment: CC (default cc), OBJC_RUNTIME (default gnustep-1.7),
#   OBJC_LIBS (default "-lobjc -lpthread"), APPKIT_SRC_DIR (another copy of AppKit/, to check the test fails there).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${APPKIT_SRC_DIR:-$root/AppKit}
prefix_flags=()
[ $# -ge 1 ] && prefix_flags=(-I"$1/include" -L"$1/lib")
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
names='_collectionBehavior|_tabbingMode'

# Declarations in the class's ivar block: from "@interface NSWindow :" to the first line that is a lone "}".
awk -v names="$names" '/^@interface NSWindow : / {on=1} on && $0 ~ "[ \t](" names ");" {print} on && /^}/ {exit}' \
    "$src/include/AppKit/NSWindow.h" >"$temp/ivars.inc"
# Declarations between "@implementation NSWindow" and its first @synthesize, static, or method.
awk -v names="$names" '/^@implementation NSWindow$/ {on=1; next} on && /^(@synthesize|static|[-+] )/ {exit}
     on && $0 ~ "[ \t](" names ");" {print}' "$src/NSWindow.m" >"$temp/prologue.inc"
[ "$(cat "$temp/ivars.inc" "$temp/prologue.inc" | grep -cE "$names")" -eq 2 ] ||
    { echo "FAIL: did not find both declarations in NSWindow.h / NSWindow.m; update $0" >&2; exit 1; }
awk '/^- \([A-Za-z]+\) (collectionBehavior|setCollectionBehavior:|tabbingMode|setTabbingMode:)[ {:(]/ {on=1; n++}
     on {print} on && /^}/ {on=0} END {exit n != 4}' "$src/NSWindow.m" >"$temp/methods.inc" ||
    { echo "FAIL: the four accessors were not found in NSWindow.m; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class \
    -DIVARS_INC="\"$temp/ivars.inc\"" -DPROLOGUE_INC="\"$temp/prologue.inc\"" \
    -DMETHODS_INC="\"$temp/methods.inc\"" \
    "${prefix_flags[@]}" "$root/tests/nswindow-window-state-host.m" ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/window-state"
"$temp/window-state"
