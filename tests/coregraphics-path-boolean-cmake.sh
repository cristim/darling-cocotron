#!/bin/sh
# Every CGPathBoolean source file must be in the CoreGraphics_sources list of
# CoreGraphics/CMakeLists.txt, or the real build leaves the functions of the
# missing file undefined (the hand-made build lines of the other tests list the
# files themselves and would not notice). Usage: sh tests/coregraphics-path-boolean-cmake.sh [CMakeLists.txt]
# Without an argument it checks the file in the tree. Exit 0 when all are listed.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
cmake=${1:-$root/CoreGraphics/CMakeLists.txt}
list=$(sed -n '/^set(CoreGraphics_sources/,/^)/p' "$cmake")
[ -n "$list" ] || { echo "FAIL: no CoreGraphics_sources list in $cmake"; exit 1; }
missing=0
for f in "$root"/CoreGraphics/src/CGPathBoolean*.c "$root"/CoreGraphics/CGPathBoolean.m; do
    rel=${f#"$root"/CoreGraphics/}
    if ! printf '%s\n' "$list" | grep -q -x "[[:space:]]*$rel"; then
        echo "FAIL: $rel is not in CoreGraphics_sources"
        missing=$((missing + 1))
    fi
done
[ "$missing" -eq 0 ] && echo "ALL PASS" && exit 0
exit 1
