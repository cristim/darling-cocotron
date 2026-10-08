# Nested layer bounds regression

`quartzcore-renderer-nested-bounds.m` checks that CARenderer places a sublayer
in its parent's bounds coordinates. Its 20-by-20 parent has bounds origin
(20, 30); the red child at (30, 40) must therefore appear at (10, 10).
The parent's own background must remain at its existing location.

The test samples both the expected child location and the location produced
when the parent's bounds origin is ignored. It exits 5 for the latter and 0
for the correct rendering.

## Verified on 2026-10-07

The same executable ran with native Wayland on a private headless Sway output.
The private Darling container was stopped before each QuartzCore replacement
and restarted before each run, so its framework mount used the staged file.

- Checkout baseline: exit 5; expected location black, displaced location red.
- Rebuilt CARenderer with the bounds-origin translation: exit 0.

Logs and the rebuilt framework are retained under
`/home/cristi/tmp-opencode/appzapper-issue120-evidence/` as
`probe-checkout-baseline.log`, `probe-checkout-fixed.log`, and
`QuartzCore-fixed.dylib`.

This establishes the renderer defect in the historical checkout. It does not
establish that the current AppZapper panel is repaired. Current integrated
Cocotron already includes the correction in commit `3f7d86c2`; actual app
verification requires the complete private runtime, including SwiftUI.

The test uses public framework APIs and pixel observations. No proprietary
implementation was inspected.
