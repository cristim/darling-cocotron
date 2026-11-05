#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Runs the real key-view selection methods of AppKit/NSWindow.m (-selectNextKeyView:, -selectPreviousKeyView:,
# -selectKeyViewFollowingView:, -selectKeyViewPrecedingView:, -keyViewSelectionDirection) and -isOnActiveSpace /
# -setShowsResizeIndicator: on the host in a mock NSWindow (no Foundation, no display). The methods, the
# NSSelectionDirection typedef and the _keyViewSelectionDirection ivar declaration (if any) are cut out of
# NSWindow.m / NSWindow.h at test time.
# Usage: tests/nswindow-key-view-direction-host.sh [OBJC_PREFIX]
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

awk '/^typedef .*NSSelectionDirection/ {on=1} on {print} on && /;$/ {exit}' \
    "$src/include/AppKit/NSWindow.h" >"$temp/typedef.inc"
grep -q NSSelectionDirection "$temp/typedef.inc" ||
    { echo "FAIL: no NSSelectionDirection typedef in NSWindow.h; update $0" >&2; exit 1; }
awk '/^@interface NSWindow : / {on=1} on && /[ \t]_keyViewSelectionDirection;/ {print} on && /^}/ {exit}' \
    "$src/include/AppKit/NSWindow.h" >"$temp/ivars.inc"
awk '/^- \([A-Za-z]+\) (selectNextKeyView|selectPreviousKeyView|selectKeyViewFollowingView|selectKeyViewPrecedingView|keyViewSelectionDirection|isOnActiveSpace|setShowsResizeIndicator|showsResizeIndicator)[ {:]/ {on=1; n++}
     on {print} on && /^}/ {on=0} END {exit n != 8}' "$src/NSWindow.m" >"$temp/methods.inc" ||
    { echo "FAIL: the eight methods were not found in NSWindow.m; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class \
    -DTYPEDEF_INC="\"$temp/typedef.inc\"" -DIVARS_INC="\"$temp/ivars.inc\"" -DMETHODS_INC="\"$temp/methods.inc\"" \
    "${prefix_flags[@]}" "$root/tests/nswindow-key-view-direction-host.m" ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/key-view-direction"
"$temp/key-view-direction"
