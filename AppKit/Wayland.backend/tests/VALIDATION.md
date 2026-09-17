# Wayland validation record

This records the September 15–16, 2026 validation of the opt-in backend. It is
fixture coverage, not a claim that the available Apple applications work.
Reproduction controls for the checked-in fixtures are in the [backend
README](../README.md).

## Published implementation units

| Commit | Completed scope | Included fixture/documentation |
|---|---|---|
| `013826c0` | M1 toplevels, CPU shm drawing, pointer/keyboard input, opt-in selection and fallback | Protocol opcode checks and native ABI design |
| `69e93fd1` | Image cursors, immutable pixel storage and logical hotspots | `waylandtest.m`, image-cursor reproduction notes |
| `3ef63c44` | M2 integer output scaling, nested popup menus and negotiated client decorations | HiDPI/popup fixture modes, decoration instructions |
| `3feac01c` | M3 clipboard portion: UTF-8 selections, bounded transfers, ownership and local named boards | `clipboardtest.m`, transfer-limit and reproduction notes |

These commits are on the branch backing
[PR #87](https://github.com/VibeDarling/darling-cocotron/pull/87).
Image cursors and clipboard are separate implementation commits. The M2 commit
keeps scaling, popup coordinate conversion and client-frame offsets together.
Incoming copy drops are covered below; outgoing drags and EGL/OpenGL subwindows remain.

## Environment and successful checks

The fixtures are plain arm64 AppKit executables. Wayland tests used a private
headless Sway compositor with the pixman renderer, virtual-pointer input,
`wtype`, and `grim` screenshots. X11 checks used an isolated Xvfb server.
The backend was compiled and linked into private output directories against the
Darling build-tree libraries; it was copied only into a dedicated test prefix.

| Area | Observed result |
|---|---|
| Native ABI | Private compile/link passed; 35 fixed-arity native functions, no variadic entries and no direct `wl_*`/`xkb_*` imports |
| M1 behavior | Drawing, pointer/scroll coordinates, Romanian typing, Return, repeat/modifiers, resize, hide/show and close delivery passed |
| Image cursors | Eight screenshot samples exactly match opaque, transparent and half-alpha reference colors at 1x; hotspot/orientation checked |
| HiDPI | 1x → 2x → 1x transitions passed; the half-point stripe occupies exactly one physical pixel at 2x |
| Popups | Nested `xdg_popup` roles and grabs observed; keyboard submenu navigation and outside cancellation return zero actions, with both server and client decorations |
| Client decorations | Close delivery passed; title dragging and border resizing changed compositor geometry; maximize/minimize requests were delivered |
| X11 compatibility | Default selection and typing passed; unavailable Wayland socket produced one fallback diagnostic and X11; both fixture processes exited naturally with status 0 |
| Clipboard | Unicode both directions, 2,100,000-byte transfers, lazy providers, ownership replacement after clear, unsupported types, clearing and an early-closing reader passed; fixture exited naturally with status 0 |
| Clipboard bounds | Stalled owner returned nil after 5.03 seconds; a 17 MiB offer was rejected with the size-limit diagnostic, rather than returned partially |

The Wayland window harness stops the remaining app during cleanup. Its success
status establishes close delivery and cleanup, not natural application exit.
Compositor policy determines whether maximize/minimize changes visibility or
geometry; request delivery alone is not a policy-independent action pass.

The clipboard boundary tests were strengthened after an intermediate run
returned nil immediately because local ownership survived a clear operation.
That bug was fixed before `3feac01c`; only the final timed and size-diagnostic
checks support the boundary claims above.

## Incoming copy-drop follow-up

The native GTK3 source (`drop-source.c`) and plain-arm64 AppKit target
(`droptest.m`) ran on the same isolated Sway compositor with Xwayland disabled.
Every case required native `SOURCE_BEGIN`, explicit target checks, exit0 and
clean prefix shutdown. The first harness used a non-event GtkLabel and produced
no drag; it was corrected to a GtkEventBox before any pass was claimed.

- Exact Unicode native-to-AppKit payload, repeated cached read, enter/update,
  prepare/perform/conclude lifecycle, and independent clipboard state passed.
- Leaving before release sends exit and no prepare/perform/conclude.
- Unsupported MIME and move-only offers do not perform a drop.
- A destination refusing preparation gets no perform/conclude callback.
- A 17 MiB offer returns nil with the explicit `exceeds 16 MiB` diagnostic;
  no conclude callback is delivered.
- A stalled source returns nil after **5.021 seconds**, with the timeout
  diagnostic and no conclude callback.
- The full clipboard suite was rerun against this backend: Unicode both ways,
  2.1 MB data, lazy publication, replacement/clear, unsupported type, broken
  reader, actual stalled-owner timeout, 17 MiB rejection and natural exit0 pass.
- Private compile/link and the 35-symbol fixed-arity ABI audit pass.

This covers incoming copy with text and unsupported-MIME fixtures at scale1.
Incoming file-URI conversion, move/link/ask, outgoing source sessions, periodic
updates, drag icons, real Apple drag destinations, and multi-output/HiDPI drops
are not validated or implemented by this follow-up. Receiver changes are hit-tested on motion and checked again at drop; cancelled/failed transfers never
send the protocol success request.

## Limits and separate app work

- At 2x, sampled image-cursor colors differ from the 1x reference by up to two
  channel values. This discrepancy is not presented as an exact pixel match.
- Multiple physical outputs, fractional scaling, clipboard-manager persistence
  after application exit, primary-selection protocols and rich-format conversion
  have not been validated or implemented as described in the README.
- The `UNPREMULT_CURSOR=1` diagnostic passes eight exact pixel samples with a
  separate private Onyx2D straight-alpha fix. That shared renderer fix is not
  part of the Wayland branch; the normal fixture uses premultiplied input.
- Separate authorized installed-only X11 checks now show TextEdit and Stickies
  rendering real document/note windows, accepting a typed marker and exiting
  normally. Stickies needed the shared libxpc missing-service invalidation fix
  before its welcome-note fallback ran. Terminal advanced past missing malloc
  and feature-query symbols, then stopped on an unimplemented
  `NSApplication userInterfaceLayoutDirection` selector. After that shared API
  fix passed its installed gate, the next Terminal attempt aborted on
  `1234 is out of bounds of array` during startup. Script Editor, Grapher and
  Automator remain pending behind the first-failure stop. None of these are
  Wayland Apple-app passes; shared library fixes are owned by separate PRs.
- Earlier Apple-runner attempts stopped during container bootstrap because of
  overlong Unix socket paths. They provide no app compatibility evidence. The
  corrected physical-prefix layout passed its bootstrap control; runtime
  cleanup and shared test-lock release were verified after each attempt.

Machine-specific build scripts, app authorization manifests, disposable-prefix
runners and screenshots remain local test artifacts. The portable fixture
sources and manual reproduction controls are checked in here.
