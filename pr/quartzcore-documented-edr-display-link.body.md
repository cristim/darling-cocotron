## Summary

Add CAEDRMetadata and CAMetalDisplayLink. Stacked on #530 (head 236d7519); each PR in this series is independent of the others.

- CAEDRMetadata: NSObject, NSCopying, NSSecureCoding; the documented factories and class properties return empty metadata, available is NO.
- CAMetalDisplayLink: NSObject; initWithMetalLayer:, the four properties, addToRunLoop:forMode:, removeFromRunLoop:forMode: and invalidate keep their state and never call the delegate.

Diff against #530: 7 files changed, 277 insertions(+).

## Why (names only)

A Notes boot under the macOS dyld cache aborts with `objc: no class for metaclass`. dyld's objc patching keeps 176 class and metaclass exports of replaced cache images because the Cocotron stand-in does not define them, so cache code keeps pointing at cache classes objc never registered. The QuartzCore image's kept list includes: CAEDRMetadata, CAMetalDisplayLink. Apple documents these classes, so they can be added from public documentation; the undocumented ones are not part of this series.

Rung 3 pages used:
- https://developer.apple.com/documentation/quartzcore/caedrmetadata
- https://developer.apple.com/documentation/quartzcore/cametaldisplaylink

## Verified

- Plain arm64 guest (Darling build of this tree on #530 plus the whole series): the new test passes, and `llvm-nm -gU` on the built QuartzCore lists `_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` for each class above; the #530 build lists neither.
- The same test binary run against the #530 build fails to start (`dyld: Symbol not found: _OBJC_CLASS_$_...`), so it fails without the change.
- arm64e, Notes under the macOS dyld cache (series applied together): not measured: the Notes boot on an AppKit relinked from master plus the open drafts stops at a missing AppKit symbol (_NSFlowLayoutCommonRowHorizontalAlignmentKey, which the earlier stage's AppKit defines) before the kept summary is printed; see the series notes.

## Not run

- This branch was not built on its own: the series was built together and the branches merge without conflicts, with no cross-dependencies.
- No window or Wayland interaction was exercised; none of these classes draws anything.
- Behaviour on a real Mac was not compared; every GUESS below needs that.

## GUESS list (rung 6, NEEDS-REAL-MAC)

- available is NO (no default is documented).
- CAMetalDisplayLinkDelegate is declared empty (method not recorded); CAMetalDisplayLinkUpdate is only forward declared.
- Defaults the page omits: not paused, zero frame rate range, zero latency.

Refs VibeDarling/darling#1475
Closes VibeDarling/darling#<issue>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
