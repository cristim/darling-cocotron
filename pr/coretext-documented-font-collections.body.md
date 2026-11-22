## Summary

Serve NSFontCollection and NSMutableFontCollection from CoreText. Stacked on #530 (head 236d7519); each PR in this series is independent of the others.

- The class moves from AppKit to CoreText (macOS exports it from CoreText); the header stays in AppKit. NSFontCollection gets its documented factories, class properties, query, exclusion and matching accessors, copy, mutableCopy and coding; NSMutableFontCollection adds the setters, addQueryForDescriptors: and removeQueryForDescriptors:.
- AppKit no longer defines the class and still links it through CoreText.

Diff against #530: 6 files changed, 321 insertions(+), 38 deletions(-).

## Why (names only)

A Notes boot under the macOS dyld cache aborts with `objc: no class for metaclass`. dyld's objc patching keeps 176 class and metaclass exports of replaced cache images because the Cocotron stand-in does not define them, so cache code keeps pointing at cache classes objc never registered. The CoreText image's kept list includes: NSFontCollection, NSMutableFontCollection. Apple documents these classes, so they can be added from public documentation; the undocumented ones are not part of this series.

Rung 3 pages used:
- https://developer.apple.com/documentation/appkit/nsfontcollection
- https://developer.apple.com/documentation/appkit/nsfontcollection/visibility
- https://developer.apple.com/documentation/appkit/nsmutablefontcollection

## Verified

- Plain arm64 guest (Darling build of this tree on #530 plus the whole series): the new test passes, and `llvm-nm -gU` on the built CoreText lists `_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` for each class above; the #530 build lists neither.
- The same test binary run against the #530 build fails to start (`dyld: Symbol not found: _OBJC_CLASS_$_...`), so it fails without the change.
- arm64e, Notes under the macOS dyld cache (series applied together): not measured: the Notes boot on an AppKit relinked from master plus the open drafts stops at a missing AppKit symbol (_NSFlowLayoutCommonRowHorizontalAlignmentKey, which the earlier stage's AppKit defines) before the kept summary is printed; see the series notes.

## Not run

- This branch was not built on its own: the series was built together and the branches merge without conflicts, with no cross-dependencies.
- No window or Wayland interaction was exercised; none of these classes draws anything.
- Behaviour on a real Mac was not compared; every GUESS below needs that.

## GUESS list (rung 6, NEEDS-REAL-MAC)

- NSFontCollectionVisibility values (names only on the page): Process 1, User 2, Computer 4.
- There is no font matching: matchingDescriptors and the matching methods return an empty array; showing, hiding and renaming a named collection return NO; allFontCollectionNames is empty.
- The notification and key constants the page lists are not defined.
- Messages the old stub swallowed (it forwarded every unknown message) now raise as unrecognized selectors.
- The coding keys NSQueryDescriptors and NSExclusionDescriptors are ours.

Refs VibeDarling/darling#1475
Closes VibeDarling/darling#<issue>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
