#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Runs the real CTFontCopyName of CoreText/CTFont.m against mock CFEqual and CTFontCopy*Name functions (no fonts,
# no runtime). The mock CFEqual halts on NULL like CoreFoundation's. The function text is extracted from the .m at
# test time. CT_SRC_DIR points at another copy of CoreText/ (used to check that the test fails there). CC overrides
# the compiler (default cc).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${CT_SRC_DIR:-$root/CoreText}
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

# The function starts at the line matching its header and ends at the first line that is a lone "}".
awk '/^CFStringRef _Nullable CTFontCopyName\(/ {on=1; found=1} on {print} on && /^}$/ {on=0} END {exit !found}' \
    "$src/CTFont.m" >"$temp/function.inc" ||
    { echo "FAIL: no CTFontCopyName in $src/CTFont.m; update tests/coretext-copy-name.sh" >&2; exit 1; }

${CC:-cc} -Wall -Wextra -DFUNCTION_INC="\"$temp/function.inc\"" \
    "$root/tests/coretext-copy-name.c" -o "$temp/copy-name"
"$temp/copy-name"
