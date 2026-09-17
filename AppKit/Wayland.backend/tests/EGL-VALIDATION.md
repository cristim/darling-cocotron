# EGL subwindow validation — 2026-09-16

## Build and runtime scope

Requires the companion Darling `CGLRegisterNativeDisplayForPlatform` change and
this Cocotron tree's CGSubWindow, QuartzCore, AppKit and Wayland backend changes.
Build `egltest.m` as plain arm64, linked to AppKit, CoreGraphics and OpenGL. The
fixture requires no pointer-authentication override and launches no Apple app.
Use a fresh private Darling prefix and an isolated headless compositor.

A minimal Sway configuration for the recorded checks is:

```text
xwayland disable
output HEADLESS-1 resolution 1280x800 position 0 0 scale 2
default_border none
default_floating_border none
focus_follows_mouse no
for_window [title="EGL test anchor"] floating enable, move position 550 10
```

Run the fixture with `DARLING_APPKIT_BACKEND=wayland`, a host-path
`WAYLAND_DISPLAY`, `LAYER_TEST=1`, `OPENGL_VIEW_TEST=1`, and `DEEP_TEST=1`.
It emits `STAGE 1` through `STAGE 16` at two-second intervals, then exits with
`RESULT failures=0` or a nonzero status. Capture each stage using the private
compositor's `grim`, preserving the original PNGs as `1.png` through `16.png`.
Keep the helper at the configured position: it otherwise occludes the tested
OpenGL view at scale 2. Give compositor presentation time before capture.

Analyze captures with:

```sh
python3 tests/check-egl-pixels.py /path/to/captures 2 deep
```

The script uses ImageMagick to read pixels; it never edits the screenshots. It
checks 64 exact color-area assertions. The non-deep fixture at scale 1 uses the
same script without `deep` (28 assertions for the first 14 stages).

## Results

| Coverage | Result |
| --- | --- |
| Private backend compile/link and native ABI audit | 38 fixed-arity native functions, no direct wl_/xkb_ imports |
| Actual layer-backed view | 6,000 blue pixels at 1x; 24,000 at 2x |
| Direct CGL child | 9,600 green pixels at 1x; 38,400 at 2x, before overlap |
| Standard NSOpenGLView | Magenta drawable, direct hide/show, reparent to clipped helper and back |
| Parent hide/show and resize | Correct visibility, no hidden-surface frame-callback hang |
| Partial crop / fully outside / re-entry | Exact visible pixels; old content never intentionally presented outside parent |
| Fractional extent / rejected invalid geometry | Rounded drawable extent and preserved valid frame |
| Parent shrink before raw child redraw | Obsolete visible child immediately suppressed |
| Overlapping sibling roles | Upper yellow child stays above lower green after lower hide/show |
| Never-mapped invalidated parent | Child swap/flush/teardown completes without creating an invalid parent role |
| Background presentation | Framework rejects before context binding or EGL swap; bounded completion |
| NULL explicit-platform registration | Early rejection preserves an already working display |
| NULL drawable attachment | Returns bad drawable without replacing the current context |
| X11 default and invalid-Wayland-socket fallback | Both backend X11Display, exact27,200 pixels per RGB region, exit0 and clean shutdown |
| Final 2x deep capture | 64/64 exact pixel assertions, app exit 0, clean prefix shutdown, no owned processes left |

The fresh Astra reviewer found and discussed hide/swap remapping, parent-resize
geometry, blocking swap pacing, CGL current-state publication, configuration
selection, scale rounding, synchronized crop/position, invalidated parents,
sibling order, background presentation, current drawable teardown, reparenting,
and failed-attachment handling. These findings were resolved and the reviewer
closed the main-thread M4 correctness review. The review does not approve broader
Wayland completeness or concurrent OpenGL rendering.

## Evidence and limits

Private reproducible build/run scripts and original captures are retained under
`/home/cristi/src/darling-gui/privbuild/wayland/m4` and `logs/` on the validation host.
Final deep evidence is `logs/codex-m4-egl-deep2-clear-20260916/`: `app.log`,
`pixels.json`, `status.json`, original PNGs, library hashes. Earlier
`codex-m4-egl-deep-final2-20260916` has failed magenta assertions because the helper
occluded the view; it is retained and excluded from the final pixel pass.

The private AppKit rebuild retained the installed NSApplication layout-direction
fix. No installed libraries were replaced. No real Apple-app rendering is
established by these fixtures; native Stickies remains a separate reviewed rerun.

Rendering is supported on the UI thread. Raw CGL callers must serialize geometry,
swap and native-child flush. No-viewporter compositors suppress partially clipped
children. Parent-window clipping does not provide arbitrary non-layer ancestor
clipping, and stacking preserves native-child creation order, not arbitrary
AppKit subview reordering. The NULL registration test covers early rejection,
not allocation failures or configuration failures after EGL initialization.
