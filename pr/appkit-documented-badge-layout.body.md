## Summary

Add NSMenuItemBadge and NSScrubberLayoutAttributes. Stacked on #530 (head 236d7519); each PR in this series is independent of the others.

- NSMenuItemBadge: NSObject, NSCopying; initWithCount: (empty string, as documented), initWithString:, the alerts/newItems/updates factories, itemCount, stringValue, type, and the NSMenuItemBadgeType constants.
- NSScrubberLayoutAttributes: NSObject, NSCopying; the documented factory, itemIndex, frame and alpha.

Diff against #530: 7 files changed, 278 insertions(+).

## Why (names only)

A Notes boot under the macOS dyld cache aborts with `objc: no class for metaclass`. dyld's objc patching keeps 176 class and metaclass exports of replaced cache images because the Cocotron stand-in does not define them, so cache code keeps pointing at cache classes objc never registered. The AppKit image's kept list includes: NSMenuItemBadge, NSScrubberLayoutAttributes. Apple documents these classes, so they can be added from public documentation; the undocumented ones are not part of this series.

Rung 3 pages used:
- https://developer.apple.com/documentation/appkit/nsmenuitembadge
- https://developer.apple.com/documentation/appkit/nsmenuitembadge/badgetype
- https://developer.apple.com/documentation/appkit/nsscrubberlayoutattributes

## Verified

- Plain arm64 guest (Darling build of this tree on #530 plus the whole series): the new test passes, and `llvm-nm -gU` on the built AppKit lists `_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` for each class above; the #530 build lists neither.
- The same test binary run against the #530 build fails to start (`dyld: Symbol not found: _OBJC_CLASS_$_...`), so it fails without the change.
- arm64e, Notes under the macOS dyld cache (series applied together): not measured: the Notes boot on an AppKit relinked from master plus the open drafts stops at a missing AppKit symbol (_NSFlowLayoutCommonRowHorizontalAlignmentKey, which the earlier stage's AppKit defines) before the kept summary is printed; see the series notes.

## Not run

- This branch was not built on its own: the series was built together and the branches merge without conflicts, with no cross-dependencies.
- No window or Wayland interaction was exercised; none of these classes draws anything.
- Behaviour on a real Mac was not compared; every GUESS below needs that.

## GUESS list (rung 6, NEEDS-REAL-MAC)

- The NSMenuItemBadgeType values (the page gives names only): None 0, Updates 1, NewItems 2, Alerts 3. initWithCount:type: gives an empty string.
- The predefined labels of the alerts, new items and updates badges are not documented; their stringValue is empty. A count or string badge has type None.
- A new layout attributes object has an empty frame and alpha 1.0.

Refs VibeDarling/darling#1475
Closes VibeDarling/darling#<issue>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
