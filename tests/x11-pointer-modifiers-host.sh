#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Replays, on its own Xvfb, a modifier release that another client's keyboard grab keeps from the window (as GNOME's
# overview does with Super), then feeds the pointer events the window gets afterwards to the real
# -modifierFlagsForState: and -syncModifierFlags... methods of AppKit/X11.backend/X11Display.m inside a mock
# X11Display (no Foundation, no AppKit). The methods are cut out of X11Display.m at test time.
# Usage: tests/x11-pointer-modifiers-host.sh [OBJC_PREFIX]
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

awk '/^- \((NSEventModifierFlags|void)\) (modifierFlagsForState:|syncModifierFlags[A-Za-z]*:)/ {on=1; n++}
     on {print} on && /^}/ {on=0} END {exit n < 1}' "$src/X11Display.m" >"$temp/methods.inc" ||
    { echo "FAIL: -modifierFlagsForState: not found in X11Display.m; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class -Wno-incomplete-implementation -DMETHODS_INC="\"$temp/methods.inc\"" \
    "${prefix_flags[@]}" "$root/tests/x11-pointer-modifiers-host.m" -lX11 -lXtst ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/pointer-modifiers"
xvfb-run -a -s '-screen 0 800x600x24' "$temp/pointer-modifiers"
