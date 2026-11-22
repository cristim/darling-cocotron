## Summary

Add NSAccessibilityCustomRotor and NSSharingServicePickerToolbarItem. Stacked on #530 (head 236d7519); each PR in this series is independent of the others.

- NSAccessibilityCustomRotor: NSObject; both initializers, type, label, itemSearchDelegate, itemLoadingDelegate and the NSAccessibilityCustomRotorType constants.
- NSSharingServicePickerToolbarItem: NSToolbarItem; delegate, the delegate protocol, other messages logged once.

Diff against #530: 7 files changed, 264 insertions(+).

## Why (names only)

A Notes boot under the macOS dyld cache aborts with `objc: no class for metaclass`. dyld's objc patching keeps 176 class and metaclass exports of replaced cache images because the Cocotron stand-in does not define them, so cache code keeps pointing at cache classes objc never registered. The AppKit image's kept list includes: NSAccessibilityCustomRotor, NSSharingServicePickerToolbarItem. Apple documents these classes, so they can be added from public documentation; the undocumented ones are not part of this series.

Rung 3 pages used:
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor
- https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor/rotortype
- https://developer.apple.com/documentation/appkit/nssharingservicepickertoolbaritem

## Verified

- Plain arm64 guest (Darling build of this tree on #530 plus the whole series): the new test passes, and `llvm-nm -gU` on the built AppKit lists `_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` for each class above; the #530 build lists neither.
- The same test binary run against the #530 build fails to start (`dyld: Symbol not found: _OBJC_CLASS_$_...`), so it fails without the change.
- arm64e, Notes under the macOS dyld cache (series applied together): not measured: the Notes boot on an AppKit relinked from master plus the open drafts stops at a missing AppKit symbol (_NSFlowLayoutCommonRowHorizontalAlignmentKey, which the earlier stage's AppKit defines) before the kept summary is printed; see the series notes.

## Not run

- This branch was not built on its own: the series was built together and the branches merge without conflicts, with no cross-dependencies.
- No window or Wayland interaction was exercised; none of these classes draws anything.
- Behaviour on a real Mac was not compared; every GUESS below needs that.

## GUESS list (rung 6, NEEDS-REAL-MAC)

- The NSAccessibilityCustomRotorType values (names only on the page): 0 for Custom, then the documented order.
- NSAccessibilityCustomRotorItemSearchDelegate, NSAccessibilityElementLoading and NSSharingServicePickerToolbarItemDelegate are declared empty: their members were not recorded.
- A label rotor has type Custom and a type rotor has an empty label.
- activityItemsConfiguration (a Mac Catalyst property of a UIKit type) is not declared.

Refs VibeDarling/darling#1475
Closes VibeDarling/darling#<issue>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
