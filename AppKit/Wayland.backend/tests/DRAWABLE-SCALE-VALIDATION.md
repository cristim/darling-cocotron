# Exact drawable size and per-window scale hooks

Fractional rendering must use the same rounded pixel allocation for EGL and the
layer viewport. `CGSubWindow.drawablePixelSize` supplies that allocation;
`CGSizeZero` means the backend does not expose it. Missing selectors and zero
preserve legacy multiplication/truncation, including tiny positive scales that
produce a zero viewport. Invalid nonzero advertised dimensions reject rendering
and clear presentation readiness. Valid dimensions override scale lookup.

`CGWindow.backingScaleFactor` supplies an optional per-window rendering scale;
zero means use the screen. NSWindow checks only its existing platform window,
accepts finite positive values, and otherwise preserves screen fallback. A
scale query must not create/map a deferred native window. Wayland currently
returns its integer effective scale; fractional protocol support is separate.

## Validation, 2026-09-16

- `drawable-size.m`: 18/18 cases. Compiles the production CALayerContext under a
  distinct class name with GL calls replaced by recording stubs. Tests missing
  selectors, zero fallback, authoritative exact pixels despite invalid scale,
  invalid dimensions, limits, tiny legacy scales, and rejection clearing stale
  presentation readiness. Establishes viewport selection and swap gating, not
  rendered pixels or an actual EGL swap.
- `window-scale.m`: 11/11 cases against the actual privately linked AppKit.
  Valid override, missing/zero/negative/nonfinite fallback, nil screen, and no
  call to the platform-window factory.
- `drawable-allocation.m`: 8/8 checks on private native Sway with Xwayland
  disabled. Actual Wayland EGL-window creation starts at 1x1 when fully clipped;
  visible allocation becomes 102x52, clipping retains it, resize becomes103x53,
  hiding retains it, native output scale2 changes it to206x106, NSWindow exposes
  scale2, and subsequent clipping retains the allocation. This checks allocation
  tracking/getters; it does not claim buffer-swap or pixel coverage.

All three fixtures exited0 and their disposable prefixes shut down cleanly.
No installed mutation, Apple app, PAC override, user-prefix or desktop access.
The native fixture used candidate backend/AppKit and the previously tested M4
OpenGL; other frameworks remained installed. Backend and three shared framework
private compile/link passed, including the 38-entry fixed-arity backend ABI audit.
Fresh Astra source review closed after the tiny-scale fallback finding was fixed.
The native allocation fixture was run after that source review.

Evidence root: `/home/cristi/src/darling-gui/privbuild/wayland/fractional/`:
`hooks-artifacts.json`, `run-drawable-size-final`, `run-window-scale-final`, and
`run-allocation`. An earlier harness failure overwrote the executable variable
with a lock filename; no fixture started, cleanup succeeded, and that failure is
preserved in `run-drawable-size-reviewed`, excluded from final evidence.

The hooks are prerequisites. Fractional protocol events, rounded pixel buffers,
viewport crops, redraws, cursor/icon scaling and pixel validation remain follow-ups.
