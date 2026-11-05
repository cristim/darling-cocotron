#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Runs the real CTFontDescriptorCreateMatchingFontDescriptor(s), CTFontDescriptorCopyLocalizedAttribute and
# CTFontManagerCopyAvailableFontFamilyNames of CoreText/ on the host against the host's fontconfig and a mock
# Foundation (no AppKit, no Onyx2D). fontconfig sees only a private directory holding three DejaVu faces, so the
# expected answers are fixed. The functions are cut out of CTFontDescriptor.m / CTFontManager.m at test time.
# Usage: tests/coretext-font-matching-host.sh [OBJC_PREFIX]
#   OBJC_PREFIX holds include/objc/runtime.h and lib/libobjc for a GNUstep-ABI runtime (libobjc2). Needs the
#   fontconfig headers and library and DejaVu fonts (FONT_DIR, default /usr/share/fonts/truetype/dejavu).
#   Environment: CC (default cc), OBJC_RUNTIME (default gnustep-1.7), OBJC_LIBS (default "-lobjc -lpthread"),
#   CT_SRC_DIR (another copy of CoreText/, to check the test fails there).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${CT_SRC_DIR:-$root/CoreText}
fonts=${FONT_DIR:-/usr/share/fonts/truetype/dejavu}
prefix_flags=()
[ $# -ge 1 ] && prefix_flags=(-I"$1/include" -L"$1/lib")
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

mkdir "$temp/fonts" "$temp/cache"
cp "$fonts/DejaVuSans.ttf" "$fonts/DejaVuSans-Bold.ttf" "$fonts/DejaVuSerif.ttf" "$temp/fonts/"
cat >"$temp/fonts.conf" <<CONF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig><dir>$temp/fonts</dir><cachedir>$temp/cache</cachedir></fontconfig>
CONF

# Functions start at their header line and end at the first lone "}"; a "static const struct" table ends at "};".
awk '/^(CFTypeRef|CFArrayRef|CTFontDescriptorRef) CTFontDescriptor(CreateWithAttributes|CopyAttribute|CopyLocalizedAttribute|CreateMatchingFontDescriptors?)\(/ ||
     /^static const struct/ {on=1; table=/^static/}
     on {print} on && (table ? /^};/ : /^}/) {on=0}' "$src/CTFontDescriptor.m" >"$temp/functions.inc"
awk '/^CFArrayRef CTFontManagerCopyAvailableFontFamilyNames\(/ {on=1} on {print} on && /^}$/ {on=0}' \
    "$src/CTFontManager.m" >>"$temp/functions.inc"
grep -q 'CTFontDescriptorCreateMatchingFontDescriptors(' "$temp/functions.inc" ||
    { echo "FAIL: matching functions not found in $src; update $0" >&2; exit 1; }
grep -q '^CFTypeRef CTFontDescriptorCopyLocalizedAttribute(' "$temp/functions.inc" && localized=1 || localized=0

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class -Wno-unused-function -DHAVE_LOCALIZED=$localized \
    -DFUNCTIONS_INC="\"$temp/functions.inc\"" -DFONT_DIR="\"$temp/fonts\"" \
    "${prefix_flags[@]}" "$root/tests/coretext-font-matching-host.m" -lfontconfig ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/font-matching"
FONTCONFIG_FILE="$temp/fonts.conf" "$temp/font-matching"
