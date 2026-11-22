# Cocotron stand-ins for documented kept classes (local branches on #530 head 236d7519, nothing pushed)

## Classes added (18)
- AppKit (13): NSTintConfiguration, NSPathControlItem, NSMenuItemBadge, NSScrubberLayoutAttributes, NSViewCornerConfiguration, NSBackgroundExtensionView, NSGlassEffectView, NSPICTImageRep, NSButtonTouchBarItem, NSStepperTouchBarItem, NSAccessibilityCustomRotor, NSSharingServicePickerToolbarItem, NSWritingToolsCoordinator.
- CoreText image (2, served from Cocotron CoreText, moved out of AppKit): NSFontCollection, NSMutableFontCollection.
- QuartzCore (3, Cocotron QuartzCore is the disk QuartzCore; Darling has no own CoreAnimation in this tree): CATiledLayer, CAEDRMetadata, CAMetalDisplayLink.

## Skipped
- Overlap: NSUserInterfaceCompressionOptions (local v2 branch feat/appkit-compression-options-v2, now PR 533); CAEAGLLayer (open PRs 514 and 523); NSTouch (open PR 508). NSFontCollection already existed in master as a forward-everything stub in AppKit; replaced by the CoreText class.
- Swift-only docs (structs, no ObjC declaration): NSSuggestionItem, NSSuggestionItemResponse, NSSuggestionItemSection.
- OUT of scope: OS_dispatch_queue_serial_executor (libdispatch; docs page not at the ObjC path either).
- None of the classes exist in master or in PRs 527-532.

## Branches (each one commit on pr530, independent, merge cleanly together)
See `git branch` feat/*; sizes: tint-path 287, badge-layout 278, view-corner 173, views-pict 355, toolbar-items 343, rotor-picker 264, writing-tools 271, font-collections 321+/38-, quartzcore-documented-layers 150, quartzcore-documented-edr-display-link 277. Commit messages and PR bodies in pr/.

## Proof
- Plain guest (union of all branches built in the plain-proof clone): 10 tests pass; `llvm-nm -gU` vs the #530 build: AppKit +13 classes and metaclasses, NSFontCollection moved out, CoreText +2, QuartzCore +3; the same test binaries against the #530 build all fail with `dyld: Symbol not found: _OBJC_CLASS_$_...` (10 of 10). plain-proof cocotron was restored to b3585a06a (it was detached there before; its build dir is left at the series build, rebuild to resync).
- Reviewed once by a cold adversarial reviewer; findings fixed (badge initWithCount:type:, PICT imageRepWithData:, nib default, CATiledLayer initWithLayer:, nil query guard, GUESS wording, overlap removal).
- arm64e / Notes: AppKit, CoreText relinked with the NL9 scripts (scratch copies under arm64e/): AppKit +14, CoreText +2 class exports (earlier union). QuartzCore relink binds _MTLCreateSystemDefaultDevice from CoreVideo and aborts dyld, so the stage kept the old QuartzCore. A Notes boot on the relinked AppKit (master + drafts 527-532 + series) stops at `Symbol not found: _NSFlowLayoutCommonRowHorizontalAlignmentKey` (the earlier combo2 AppKit has it; master plus drafts do not), before any kept summary. Kept count change NOT measured; only 1 boot run, no installed dyld changed, sway stopped, no secrets in logs.

## Not done
No per-branch standalone build; no CAEAGLLayer/NSTouch; no arm64e kept count; Notes next wall not reachable until AppKit has the combo2 symbols.
