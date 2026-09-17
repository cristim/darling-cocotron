# OpenGL view backing coordinates and reshape

NSOpenGLView now maps backing coordinates to its actual drawable dimensions,
when the backend supplies them, and reshapes when those dimensions change. A
101×51 point drawable may allocate 126×64 pixels: multiplying every coordinate
by the window's nominal scale does not describe that buffer exactly. Full bounds
map exactly to integral pixel dimensions, including the 71→124 rounding case.
The view does not change the application's GL viewport automatically; applications
can use `convertRectToBacking:` from `reshape` to set it.

Queries use an existing context and do not create a drawable. Missing or invalid
dimensions retain inherited conversions. Reshape runs only after successful
attachment to the same context and view. Paired focus calls retain the context
that was actually locked across application callbacks; reshape exceptions retain
the retry flag and unwind that lock. Context replacement clears cached dimensions.

## Validation — 2026-09-17

- `gl-backing-conversion.m`: **644 checks pass** against the actual private
  AppKit, with a fake context-size provider. Covers all six conversions, inverse
  mapping, nonzero bounds origins, 257 exact full extents, invalid dimensions,
  inherited fallback, detached/other-view context ownership, and no implicit
  context creation. The pre-fix baseline fails all 16 ownership assertions. This does not exercise
  a real GL context or focus callbacks.
- Additional private native Wayland integration: **22 app checks and 24
  screenshot regions pass** at 125%, 150%, and 175%. Two static 101×51 GL views
  reshape/redraw to 126×64, 152×77, and 177×89 after actual compositor events.
  Full-NDC colored geometry reaches the last physical pixel with no GL error;
  untouched compositor captures contain expected CPU, GL and layer regions.
  A `prepareOpenGL` callback clears the raw CGL context: the pre-fix baseline
  wrongly reshapes (one failed check), while the candidate defers reshape until
  successful reattachment. One GL view is clipped at the parent's right edge. Uniform color checks do
  not establish exact source crop offsets or one-pixel boundaries.

The native integration used the separately developing fractional Wayland
backend and private drawable-hook frameworks. That backend is **not included
in this OpenGL view change**. It is corroborating integration evidence, not a
claim that the hook-only backend implements fractional rendering. Framework
and fixture hashes are recorded in `gl-guards-candidate/manifest.json`.

All runs exited zero with clean prefix shutdown and no owned handles remaining.
No installed changes, Apple apps, PAC overrides, or user-prefix access.
Fresh Astra reviews covered the context identity/attachment checks, paired
unlock, exception retry, conversions, and the integration fixture's assertions.
The raw CGL callback guard has baseline/fixed runtime coverage. Context-object
replacement and exception paths have source review but no dedicated runtime coverage. Independent surface preferences and rotated views are not
claimed by these tests.

Evidence under `/home/cristi/src/darling-gui/privbuild/wayland/fractional/`:
`run-gl-backing-conversion-guards-{baseline,candidate}`,
`run-gl-context-{baseline,candidate}`, and
`gl-guards-candidate/manifest.json`. The earlier `run-fractional-live-first`
used `glClear` at the edge; because clear ignores the viewport, its readback
must not be used as viewport correctness evidence.
