# Shape layer with a displayLayer: delegate, and layer.transform

`quartzcore-renderer-shape-transform.m` renders a red 20x10 CAShapeLayer, centred at
(32, 32) and rotated 90 degrees about its anchor, whose delegate implements
`-displayLayer:` without setting contents. Rotated, it covers x 27-37, y 22-42, so
(32, 40) is red and (24, 32) is black. Exit 5: nothing drawn (the delegate suppressed the
path); exit 6: transform ignored; exit 0: correct.

Build and run it like `quartzcore-renderer-nested-bounds.m` (see its `.md`).

## Status

Written and the source fix applied (`CALayer -_drawsOwnContent`, `CAShapeLayer`
override, `CARenderer` transform), but **not yet built or run**: that needs the private
parent build and a private prefix. The baseline-fails / candidate-passes result is
still to be recorded here.
