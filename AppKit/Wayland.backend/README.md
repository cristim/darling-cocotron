# Darling AppKit Wayland backend

This backend draws Cocotron AppKit windows directly on a Wayland compositor.
It is opt-in; X11 remains the default. This combined branch includes the reviewed
input, drag-and-drop and EGL milestones, with the integration limits below.

## Selecting it

Build/install the backend with Darling, then select it for the application:

```sh
export WAYLAND_DISPLAY=/absolute/host/path/to/wayland-socket
darling shell env DARLING_APPKIT_BACKEND=wayland \
  WAYLAND_DISPLAY="$WAYLAND_DISPLAY" /path/to/application
```

The socket path is a **host** path, not a `/Volumes/SystemRoot` guest path:
native libwayland opens it. Without the selector, AppKit uses X11. Missing native
libraries, unavailable compositor or required globals cause a logged fallback
to the next backend. An older OpenGL runtime without the explicit Wayland EGL
registration API still permits CPU drawing and reports unavailable EGL support.

CMake requires wayland-client >= 1.20, wayland-cursor, xkbcommon,
wayland-protocols headers and wayland-scanner. It skips this backend when build
dependencies are missing. Native libraries load on demand through fixed-arity
Darwin/Linux bridges. Generated protocol tables are checked against request/event
names at startup; native variadic functions and libffi listener dispatch are not
used.

## Implemented and tested

| Area | Behavior and evidence |
| --- | --- |
| Windows | xdg toplevels, redraw/resize, hide/show, popups and client/server decorations; [initial validation](tests/VALIDATION.md) |
| Outputs | Atomic core updates, rotation, removal/reappearance, optional compositor logical topology; [core](tests/OUTPUT-VALIDATION.md) and [logical](tests/LOGICAL-OUTPUT-VALIDATION.md) validation |
| Input | Pointer/click grouping, frame-coalesced scrolling, text/repeat and independent physical modifiers; [input validation](tests/INPUT-VALIDATION.md) and [scroll-frame validation](tests/SCROLL-FRAME-VALIDATION.md) |
| Scale and cursors | Integer buffer scale, named/image cursors, scaled drag icons; [icon validation](tests/DRAG-ICON-VALIDATION.md) |
| Clipboard and dragging | Clipboard ownership/transfer, incoming/outgoing COPY/MOVE, bounded immutable data; [outgoing](tests/OUTGOING-VALIDATION.md) and [actions](tests/DRAG-ACTIONS-VALIDATION.md) |
| Filenames | Host-backed file URI conversion; [URI limits](tests/FILE-URI-VALIDATION.md) |
| Local-only dragging | Original Cocoa bytes stay in process, including guest-only paths; [privacy/lifecycle validation](tests/LOCAL-DRAG-VALIDATION.md) |
| OpenGL/layers | Main-thread EGL subwindows, NSOpenGLView/layer presentation, integer scale and parent clipping; [combined interactions](tests/COMBINED-VALIDATION.md) |

The [combined fixture](tests/integrationtest.m) exercises these components in the
same application: input through GL children, modifier changes during a held mouse
press, drag cancellation/remapping and live 1x→2x scale changes. Its framework
composition and exact evidence are recorded separately from installed readiness.

## Remaining gaps and compositor constraints

- No fractional-scale protocol, pointer constraints/relative pointer, or global
  pointer warping. Integer 1x/2x rendering does not establish fractional coverage.
- Toplevel position/focus/stacking are compositor-controlled. Reported positions
  and drag-end coordinates use the backend's virtual origin. Minimized state is
  not reported by xdg-shell; `isMiniaturized` cannot reflect it reliably.
- Whole-window alpha, explicit shadow control, attention requests and cursor
  capture are not implemented. CoreGraphics global window-server queries are
  not supplied by this backend.
- Primary selection and clipboard persistence after application exit are absent.
- Guest-only file export to other processes, file promises, modern dragging
  sessions, ASK UI and slide-back remain absent. Core drag actions lack LINK.
  Different simultaneous local/external action sets are not negotiated separately.
- EGL presentation on background threads is rejected. Arbitrary ancestor clipping
  and complete mixed-view stacking are not established. The companion explicit
  EGL registration API and AppKit/QuartzCore presentation hooks are required.
- Private headless-compositor tests do not prove every desktop compositor, input
  device, monitor transition, accessibility/IME path, or macOS application works.

See each validation note for precise coverage and failure cases. This is a
working set of backend milestones, not full macOS window-server parity.

## Manual regression recipes

The following recipes complement the milestone-specific validation records.
Use a dedicated prefix and compositor; historical shared-renderer limitations
are distinguished from the private candidate composition tested above.

## Manual regression application

Build `tests/waylandtest.m` as a plain arm64 executable linked against AppKit with
your Darling SDK/toolchain. It does not need pointer authentication disabled.
Run it in a dedicated test prefix and compositor; set `DARLING_APPKIT_BACKEND` to
`wayland` and `WAYLAND_DISPLAY` to the compositor's host socket path.

The application draws red/green/blue views, a text view, and a second yellow window.
It logs input events, text, geometry, activation, and close delivery. Right-click
the red view to hide/re-show the second window. `EXIT_AFTER` controls its exit
timer (seconds); keep the second window visible while testing close on the first.

Set `IMAGE_CURSOR=1` to register a 32x24 image cursor over the red view, with
hotspot (5,7). With the pointer held over that view, capture using `grim -c`:

- Left 16 columns: magenta upper half, cyan lower half.
- Next 8 columns: transparent, preserving the red background.
- Right 8 columns: half-alpha magenta/cyan, blending over red.
- The image starts five pixels left and seven pixels above the pointer.

Move into the text view to restore the themed I-beam. Leave/re-enter the window,
resize it, and hide/re-show the second window. Test Romanian text `Hello ăîșț`,
key repeat and modifiers, then compositor close (`windowWillClose` in the log).

Also run without the selector variable on an isolated X server to verify
`backend X11Display` and typing, then with Wayland selected and an invalid socket:
one fallback message and an X11 window should result.

`UNPREMULT_CURSOR=1` selects an additional shared-renderer diagnostic: it uses
an unpremultiplied NSBitmapImageRep. Onyx2D's current 8-bit image reader does not
correctly premultiply this input, so transparent/partial-alpha pixels can render
incorrectly. The normal fixture supplies premultiplied data to test the backend
independently of that shared drawing issue.

## HiDPI, menus and decorations

Surface output membership controls integer HiDPI rendering and cursor scale.
Set `HIDPI_TEST=1` and change the test output between scale 1 and 2: the half-point
white stripe in the red view should become one physical pixel wide at scale 2.
Input coordinates and AppKit window dimensions remain logical.

Menus use `xdg_popup` with parent-relative placement and nested grabs.
`POPUP_TEST=1` opens a context menu from the green view. Open its Branch submenu,
then click outside; cancellation must log `popup returned actions=0`.
Repositioning requires xdg-shell version 3.

Titled windows negotiate decorations and draw a client frame when requested by
the compositor or when the decoration protocol is absent. Set
`DARLING_WAYLAND_DECORATIONS=client` to request this path explicitly. Test close,
minimize, maximize, title-bar move and border resize. Compositor policy determines
final placement and supported actions.

Headless Sway validation covers 1x/2x/1x transitions, nested menu grabs and
outside-click cancellation, typing, resize, hide/show and client close delivery.
Client title dragging and border resizing change compositor geometry; maximize
and minimize requests are delivered, with final behavior governed by policy.
The half-point stripe is exactly one physical pixel at 2x. Historical image-cursor
captures differed by up to two channel values at 2x; the separate Onyx resampling
candidate and exact corrected captures are recorded in tests/DRAG-ICON-VALIDATION.md.
Two headless outputs now have rotation/scale/removal coverage in the output
validation record. Multiple physical outputs and fractional scales remain unvalidated.

## Clipboard

The general pasteboard uses `wl_data_device`. UTF-8 text maps to
`text/plain;charset=utf-8`, `text/plain` and `UTF8_STRING`; other pasteboard types
are exposed under their own names, except `NSFilenamesPboardType`, which converts
to `text/uri-list` for explicit host-root paths (see
[URI validation](tests/FILE-URI-VALIDATION.md)). Other named pasteboards are process-local.
Publishing requires keyboard focus and an input serial; writes made beforehand
remain local until input is available. Providers are materialized outside native
Wayland dispatch, and each published source uses an immutable snapshot.

Transfers are limited to 16 MiB and five seconds. A dedicated writer keeps a slow
reader off the UI thread and handles broken pipes without changing process-wide
SIGPIPE behavior. Synchronous reads service compositor events while waiting and
return nil on timeout, oversize or ownership replacement, never truncated data.

Build `tests/clipboardtest.m` like the window fixture. Set `CLIPBOARD_INPUT` and
`CLIPBOARD_RESULT` to dedicated guest-accessible scratch files. With its window
focused, `c` copies input bytes as UTF-8 text, `l` declares a lazy provider, `p`
writes received text bytes to the result file, `u` checks an unsupported type,
`e` clears, `r` checks a failing bounded read, and `q` exits. Native `wl-copy` and
`wl-paste` can exercise both directions on the same private compositor.

Validated: Unicode both ways, 2.1 MB transfers, lazy providers, replacement after
clear, early reader closure, a 5.03-second stalled-owner timeout, 17 MiB rejection
and natural fixture exit0. This is fixture coverage, not real Apple-app coverage.


## Incoming drag regression recipe

Incoming and outgoing COPY/MOVE are supported as detailed in
[the action tests](tests/DRAG-ACTIONS-VALIDATION.md). The original incoming
fixture also retains these bounded refusal and transfer checks:

Build `tests/droptest.m` like the other plain-arm64 AppKit fixtures. Build the
native source with `cc tests/drop-source.c -o drop-source $(pkg-config --cflags
--libs gtk+-3.0)` (run from this directory). Use a private compositor with Xwayland
disabled and a dedicated Darling prefix containing this backend. Both processes
use `DROP_MODE`, one of `accept`, `leave`, `unsupported`, `move-only`,
`prepare-reject`, `oversize`, or `timeout`. Drag from the GTK source to the green
AppKit view, move within the target, and release. For `leave`, move outside both
windows before releasing. The target exits after 18 seconds, with an exact
callback/payload/clipboard-independence check and a nonzero status on failure.
The timeout case must log an actual five-second wait; the oversized case must log
`Wayland drop: transfer exceeds 16 MiB`, not merely return nil. Source logs must
show `SOURCE_BEGIN` so failed input injection cannot masquerade as rejection.

## EGL and OpenGL subwindows

Layer-backed views and `NSOpenGLView` use native `wl_egl_window` drawables and
synchronized `wl_subsurface` children. The parent retains its native surface
across hide/show. Child EGL surfaces must be destroyed before their native
windows; current contexts are detached when replacing drawables.

This requires Darling's additive `CGLRegisterNativeDisplayForPlatform` API and
native `libwayland-egl`. The backend explicitly selects the Wayland EGL platform;
it does not modify `EGL_PLATFORM`. If either capability is unavailable, CPU
windows still work and the backend reports that EGL subwindows are unavailable.
New explicit-platform contexts default to swap interval zero, avoiding waits for
frame callbacks on hidden surfaces. Explicit caller swap-interval requests are
preserved. The existing X11 registration keeps its original default.

Integer output scale determines drawable pixels and layer viewports. With
`wp_viewporter`, child content is cropped to parent content bounds; position,
crop, scale and the rendered buffer are presented together after a successful
swap. Without that optional protocol, fully contained children render but
partially clipped children are suppressed. Hidden children stay hidden even if
their owner keeps drawing. Re-created child roles retain sibling creation order.

Geometry, rendering and presentation currently require the main/UI thread.
The AppKit/QuartzCore wrappers reject background Wayland binding or presentation;
raw CGL callers must keep geometry, swap and child `flush` on that thread too.
This is not support for concurrent OpenGL rendering. Parent-window clipping does
not implement arbitrary clipping through non-layer-backed ancestor views.

`tests/egltest.m` tests direct CGL, real layer-backed views (`LAYER_TEST=1`) and
standard OpenGL views (`OPENGL_VIEW_TEST=1`). `DEEP_TEST=1` adds overlapping child
surfaces. The bounded sequence covers hide/swap/show, parent hide/show, resize,
partial/outside clipping, invalid/fractional geometry, parent shrink before
redraw, drawable replacement across windows, invalidated never-mapped parents,
and background-presentation rejection. GL readback checks and compositor pixel
captures are separate evidence; a successful swap alone is not a rendering pass.
See `tests/EGL-VALIDATION.md` for reproducible setup and exact limits.

Cursor image callback lifetime and stale-presentation regression: [validation](tests/CURSOR-CALLBACK-VALIDATION.md).

Exact drawable-size and per-window scale prerequisites: [validation](tests/DRAWABLE-SCALE-VALIDATION.md).
