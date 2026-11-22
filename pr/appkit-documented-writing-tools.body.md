## Summary

Add NSWritingToolsCoordinator. Stacked on #530 (head 236d7519); each PR in this series is independent of the others.

- NSWritingToolsCoordinator: NSObject; initWithDelegate:, the documented properties and methods, and the behavior, result option, state, text update reason and text animation constants. isWritingToolsAvailable is NO; the action methods log once and do nothing.

Diff against #530: 5 files changed, 271 insertions(+).

## Why (names only)

A Notes boot under the macOS dyld cache aborts with `objc: no class for metaclass`. dyld's objc patching keeps 176 class and metaclass exports of replaced cache images because the Cocotron stand-in does not define them, so cache code keeps pointing at cache classes objc never registered. The AppKit image's kept list includes: NSWritingToolsCoordinator. Apple documents these classes, so they can be added from public documentation; the undocumented ones are not part of this series.

Rung 3 pages used:
- https://developer.apple.com/documentation/appkit/nswritingtoolscoordinator
- https://developer.apple.com/documentation/appkit/nswritingtoolsbehavior
- https://developer.apple.com/documentation/appkit/nswritingtoolsresultoptions

## Verified

- Plain arm64 guest (Darling build of this tree on #530 plus the whole series): the new test passes, and `llvm-nm -gU` on the built AppKit lists `_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` for each class above; the #530 build lists neither.
- The same test binary run against the #530 build fails to start (`dyld: Symbol not found: _OBJC_CLASS_$_...`), so it fails without the change.
- arm64e, Notes under the macOS dyld cache (series applied together): not measured: the Notes boot on an AppKit relinked from master plus the open drafts stops at a missing AppKit symbol (_NSFlowLayoutCommonRowHorizontalAlignmentKey, which the earlier stage's AppKit defines) before the kept summary is printed; see the series notes.

## Not run

- This branch was not built on its own: the series was built together and the branches merge without conflicts, with no cross-dependencies.
- No window or Wayland interaction was exercised; none of these classes draws anything.
- Behaviour on a real Mac was not compared; every GUESS below needs that.

## GUESS list (rung 6, NEEDS-REAL-MAC)

- All constant values are guesses (the pages give names only); NSWritingToolsBehaviorNone is -1.
- The delegate protocol is declared empty (members not recorded); NSWritingToolsCoordinatorContext is only forward declared; the context scope, text decoration and text replacement reason enums are not declared.
- Defaults the page omits: preferred behavior Default, preferred result options Default, effective behavior None, state Inactive.

Refs VibeDarling/darling#1475
Closes VibeDarling/darling#<issue>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
