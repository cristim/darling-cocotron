#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Runs the real decoration code of AppKit/X11.backend/X11Window.m (-setStyleMask:, -setStyleMaskInternal:force:,
# +removeDecorationForWindow:onDisplay:, any -updateDecorations... helper and the end of -initWithDelegate:) and the
# title bar accessors of AppKit/NSWindow.m on the host against its own Xvfb, inside mock classes (no Foundation, no
# AppKit). The code is cut out of the sources at test time.
# Usage: tests/x11-decorations-host.sh [OBJC_PREFIX]
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

# Cut whole methods whose first line matches $1 out of $2; fail unless at least $3 are found.
cut_methods() {
    awk -v re="$1" -v want="$3" '$0 ~ re {on=1; n++} on {print} on && /^}/ {on=0} END {exit n < want}' "$2"
}
cut_methods '^[-+] \(void\) (setStyleMask:|setStyleMaskInternal:|removeDecorationForWindow:|updateDecorations[A-Za-z]*)' \
    "$src/X11.backend/X11Window.m" 3 >"$temp/x11window.inc" ||
    { echo "FAIL: decoration methods not found in X11Window.m; update $0" >&2; exit 1; }
cut_methods '^- \((BOOL|NSWindowTitleVisibility|void)\) (setT|t)it(lebarAppearsTransparent|leVisibility)[ :{]' \
    "$src/NSWindow.m" 4 >"$temp/nswindow.inc" ||
    { echo "FAIL: title bar accessors not found in NSWindow.m; update $0" >&2; exit 1; }

# The end of -initWithDelegate:, from registering the window to its first style mask (isPanel is its local).
awk '/setWindow: self forID: _window\];/ {on=1; next} on {print} on && /setStyleMaskInternal: _styleMask force: YES\];/ {found=1; exit}
     END {exit !found}' "$src/X11.backend/X11Window.m" >"$temp/init.inc" ||
    { echo "FAIL: end of -initWithDelegate: not found in X11Window.m; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class \
    -DX11WINDOW_INC="\"$temp/x11window.inc\"" -DINIT_INC="\"$temp/init.inc\"" -DNSWINDOW_INC="\"$temp/nswindow.inc\"" \
    "${prefix_flags[@]}" "$root/tests/x11-decorations-host.m" -lX11 ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/decorations"
xvfb-run -a -s '-screen 0 800x600x24' "$temp/decorations"
