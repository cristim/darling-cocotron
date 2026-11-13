#!/bin/bash
# usage: check-boundary.sh <UIFoundation dylib> <AppKit dylib>
# UIFoundation sits below AppKit: it must not depend on AppKit, and AppKit may import from it only the public text
# classes and attribute constants, because a process served by another UIFoundation (macOS's) provides nothing else.
# Reads load commands and symbol tables of Darling's own build output only.
set -u
UIF=$1; AK=$2; bad=0
CLASSES="NSATSTypesetter NSAdaptiveImageGlyph NSDataAsset NSFont NSFontDescriptor NSGlyphGenerator NSGlyphInfo NSLayoutManager NSMutableParagraphStyle NSParagraphStyle NSShadow NSTextAttachment NSTextBlock NSTextContainer NSTextContentManager NSTextContentStorage NSTextLayoutManager NSTextList NSTextRange NSTextStorage NSTextTab NSTextTable NSTextTableBlock NSTypesetter UINibEncoder _NSAttributeRun _NSAttributes"
allowed_classes=$(printf '%s|' $CLASSES); allowed_classes=${allowed_classes%|}

if llvm-otool -L "$UIF" | tail -n +2 | grep -q "/AppKit"; then
    echo "FAIL: $UIF depends on AppKit"; bad=1
fi
llvm-nm -g --defined-only "$AK" | awk 'NF==3{print $3}' | sort -u > "${TMPDIR:-/tmp}/ak-defs.$$"
llvm-nm -u "$UIF" | sort -u | comm -12 - "${TMPDIR:-/tmp}/ak-defs.$$" | while read -r s; do
    echo "FAIL: $UIF imports $s, which AppKit defines"; echo x > "${TMPDIR:-/tmp}/bad.$$"
done
llvm-nm -u "$AK" | sort -u > "${TMPDIR:-/tmp}/ak-undef.$$"
llvm-nm -g --defined-only "$UIF" | awk 'NF==3{print $3}' | sort -u | comm -12 "${TMPDIR:-/tmp}/ak-undef.$$" - | while read -r s; do
    if ! echo "$s" | grep -Eq "^_OBJC_(META)?CLASS_\\\$_($allowed_classes)\$|^_NS[A-Za-z]+(AttributeName|Attribute|Notification)\$"; then
        echo "FAIL: AppKit imports $s from UIFoundation, which is not a public text class or constant"; echo x > "${TMPDIR:-/tmp}/bad.$$"
    fi
done
[ -e "${TMPDIR:-/tmp}/bad.$$" ] && bad=1
rm -f "${TMPDIR:-/tmp}/bad.$$" "${TMPDIR:-/tmp}/ak-defs.$$" "${TMPDIR:-/tmp}/ak-undef.$$"
[ $bad -eq 0 ] && echo "uifoundation boundary ok"
exit $bad
