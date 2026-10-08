# Shape layer with a displayLayer: delegate, and layer.transform

`quartzcore-renderer-shape-transform.m` renders a red 20x10 CAShapeLayer, centred at
(32, 32) and rotated 90 degrees about its anchor, whose delegate implements
`-displayLayer:` without setting contents. Rotated, it covers x 27-37, y 22-42, so
(32, 40) is red and (24, 32) is black. Exit 5: nothing drawn (the delegate suppressed the
path); exit 6: transform ignored; exit 0: correct.

Build and run it like `quartzcore-renderer-nested-bounds.m` (see its `.md`).

## Verified on 2026-10-08

Native Wayland on a private headless Sway, private Darling prefix, QuartzCore swapped
between runs (container shut down first).

- Checkout baseline QuartzCore: exit 5 ("shape layer drew nothing"); nested-bounds exit 5.
- QuartzCore rebuilt from this tree (CALayer, CAShapeLayer, CARenderer): both tests exit 0.

Logs, scripts and the rebuilt dylib are in `/home/cristi/tmp-opencode/appzapper-issue120-evidence/`.
Not established: the real AppZapper panel, which needs the SwiftUI runtime (still blocked
on the strict-link closure). The delegate and transform fixes are not separated by their own
probes; the baseline lacks both.
