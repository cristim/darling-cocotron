# Handover: darling-cocotron-pr-flipped-layer-placem-06 (AppZapper #120 + SwiftUI ABI investigation)

## Task
VibeDarling/darling #120 (Wayland black upper panel, clipped text in AppZapper), then the SwiftUI Apple-ABI-on-OpenSwiftUI feasibility investigation.

## Done
- CAShapeLayer drawn despite a displayLayer: delegate: darling-cocotron PR #422, merged (closes darling#1119). CLAIMS.md row released.
- Bounds-origin and layer.transform handling in CARenderer: already on cocotron master; nothing left to push for source. Local tests tests/quartzcore-renderer-nested-bounds.{m,md} (commit d39d488ed) are not on master; not yet run against master.
- Feasibility report: ~/tmp-opencode/coordination/SWIFTUI-ABI-FEASIBILITY.md (draft, user ruling recorded: no .swiftinterface/SDK-derived interface text).
- Symbol diff harness: ~/tmp-opencode/swiftui-abi/symbol-diff.sh. AppZapper demand 489 SwiftUI symbols, 481 defined by our 891 compiled objects, 8 missing (all _TaskModifier2 / _TaskValueModifier2). Outputs in ~/tmp-opencode/swiftui-abi/out.
- OpenSwiftUI fork rebased onto upstream/main 4fa65735: worktree ~/src/OpenSwiftUI-rebase-upstream, branch darling-rebased-20261009 (50 commits + a2b13994). Conflict log ~/tmp-opencode/swiftui-abi/rebase-conflicts.log. NOT compiled, NOT pushed.

## In progress / blocked
- Stale test fixed: 72421496 moves ContentShapeDataTests to Tests/OpenSwiftUITests/Event/Responder/ContentShapeModifierTests.swift, ported to upstream's _ContentShapeModifier. NOT compiled/run (needs Darling toolchain). Commit a2b13994 still has a Co-Authored-By trailer; amending was denied, so decide whether to keep it (user's global rule: no Claude mention).
- Local branch fix/flipped-view-layer-placement (dda054a9a, d39d488ed, 84b3c534a) unpushed, stacked on predecessor's 94 commits; source part is superseded by master.
- 85 unresolved SwiftUI strict-link APIs: slices file ~/tmp-opencode/coordination/swiftui-closure-slices.md; slices on HOLD until coordinator confirms. CGImageGetHeadroom is cocotron PR #424 (darling-ce).
- Real AppZapper launch blocked: dyld "SwiftUI.framework image not found"; evidence ~/tmp-opencode/appzapper-issue120-evidence/ (STATUS.md).

## Next steps
1. Decide the a2b13994 trailer question.
2. Compile the rebased branch under the heavy lock (flock -w 1800 /tmp/agent-locks/darling-heavy-build.lock, jobs 1) with Darling/build-objects.sh; rerun symbol-diff.sh.
3. Add _TaskModifier2/_TaskValueModifier2 from public task(name:executorPreference:priority:_:) docs (Sources/OpenSwiftUI/Modifier/ViewModifier/TaskModifier.swift); local commit, no push before report review.
4. After slice hold lifts: CoreText 14, QuartzCore 12, AppKit 8 slices; then package SwiftUI.framework in a private prefix and gate AppZapper (dyld load, window opens, A/B black panel/clipping).
5. Decide target arch: AppZapper is x86_64, build is arm64 only.

## Constraints to keep
Clean-room (AGENTS.md; allowed sources per user ruling above), private prefix only, no /tmp scratch, no push before report review, claims via CLAIMS.md under flock.
