#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Runs the real -[NSThemeFrame resizeSubviewsWithOldSize:] and +titleBarHeightForStyleMask: of
# AppKit/NSThemeFrame.m on the host in a mock view hierarchy (no Foundation, no display). The methods are cut out
# of NSThemeFrame.m at test time.
# Usage: tests/themeframe-content-resize-host.sh [OBJC_PREFIX]
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

awk '/^@implementation NSThemeFrame$/ {in_class=1}
     in_class && /^[-+] \([A-Za-z]+\) (resizeSubviewsWithOldSize|titleBarHeightForStyleMask):/ {on=1; n++}
     on {print} on && /^}/ {on=0} END {exit n != 2}' "$src/NSThemeFrame.m" >"$temp/methods.inc" ||
    { echo "FAIL: NSThemeFrame methods not found in NSThemeFrame.m; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class -DMETHODS_INC="\"$temp/methods.inc\"" \
    "${prefix_flags[@]}" "$root/tests/themeframe-content-resize-host.m" ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/themeframe"
"$temp/themeframe"
