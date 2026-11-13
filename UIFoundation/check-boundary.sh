#!/bin/bash
# usage: check-boundary.sh <UIFoundation dylib> <AppKit dylib>
# UIFoundation sits below AppKit: it must not depend on AppKit, and AppKit may import from it only the public text
# classes and attribute constants, because a process served by another UIFoundation (macOS's) provides nothing else.
# Reads load commands and symbol tables of Darling's own build output only.
set -u
UIF=$1; AK=$2; bad=0
tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT
CLASSES="NSATSTypesetter NSAdaptiveImageGlyph NSDataAsset NSFont NSFontDescriptor NSGlyphGenerator NSGlyphInfo NSLayoutManager NSMutableParagraphStyle NSParagraphStyle NSShadow NSTextAttachment NSTextBlock NSTextContainer NSTextContentManager NSTextContentStorage NSTextLayoutManager NSTextList NSTextRange NSTextStorage NSTextTab NSTextTable NSTextTableBlock NSTypesetter UINibEncoder _NSAttributeRun _NSAttributes"
allowed_classes=$(printf '%s|' $CLASSES); allowed_classes=${allowed_classes%|}

if llvm-otool -L "$UIF" | tail -n +2 | grep -q "/AppKit"; then
    echo "FAIL: $UIF depends on AppKit"; bad=1
fi
llvm-nm -g --defined-only "$AK" | awk 'NF==3{print $3}' | sort -u > "$tmp/ak-defs"
while read -r s; do
    echo "FAIL: $UIF imports $s, which AppKit defines"; bad=1
done < <(llvm-nm -u "$UIF" | sort -u | comm -12 - "$tmp/ak-defs")
llvm-nm -u "$AK" | sort -u > "$tmp/ak-undef"
while read -r s; do
    if ! echo "$s" | grep -Eq "^_OBJC_(META)?CLASS_\\\$_($allowed_classes)\$|^_NS[A-Za-z]+(AttributeName|Attribute|Notification)\$"; then
        echo "FAIL: AppKit imports $s from UIFoundation, which is not a public text class or constant"; bad=1
    fi
done < <(llvm-nm -g --defined-only "$UIF" | awk 'NF==3{print $3}' | sort -u | comm -12 "$tmp/ak-undef" -)
[ $bad -eq 0 ] && echo "uifoundation boundary ok"
exit $bad
