#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Runs the real mapping methods of AppKit/X11.backend/X11Window.m (-ensureMapped*, -placeAboveWindow:,
# -placeBelowWindow:, -makeKey, -hideWindow) on the host against its own Xvfb, inside a mock X11Window class
# (no Foundation, no AppKit). The methods are cut out of X11Window.m at test time.
# Usage: tests/x11-hidden-window-host.sh [OBJC_PREFIX]
#   OBJC_PREFIX holds include/objc/runtime.h and lib/libobjc for a GNUstep-ABI runtime (libobjc2); without it the
#   compiler's default search paths are used. Environment: CC (default cc), OBJC_RUNTIME (default gnustep-1.7),
#   OBJC_LIBS (default "-lobjc -lpthread"), X11_SRC_DIR (another copy of AppKit/X11.backend/, to check the test
#   fails there).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${X11_SRC_DIR:-$root/AppKit/X11.backend}
prefix_flags=()
[ $# -ge 1 ] && prefix_flags=(-I"$1/include" -L"$1/lib")
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

awk '/^- \(void\) (ensureMapped[A-Za-z]*|placeAboveWindow:|placeBelowWindow:|makeKey|hideWindow)[ {]/ {on=1; n++}
     on {print} on && /^}/ {on=0} END {exit n < 5}' "$src/X11Window.m" >"$temp/methods.inc" ||
    { echo "FAIL: mapping methods not found in X11Window.m; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class -DMETHODS_INC="\"$temp/methods.inc\"" \
    "${prefix_flags[@]}" "$root/tests/x11-hidden-window-host.m" -lX11 ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/hidden-window"
xvfb-run -a -s '-screen 0 800x600x24' "$temp/hidden-window"
