# Logical output topology

The optional xdg-output extension supplies compositor logical position and size.
When every mode-bearing output has complete committed metadata, screen frames
use it directly: no additional rotation or scale division. Convert Wayland's
Y-down layout to Cocoa Y-up with the first mode-bearing screen at (0,0):
`(x-firstX, firstY+firstHeight-y-height, width, height)`. Arithmetic uses CGFloat
before adding/subtracting potentially extreme signed protocol coordinates.

The compositor supplies no primary-screen selection here; first means registry
order among surviving mode-bearing outputs. Missing/incomplete metadata uses a
whole-set horizontal core-output fallback, never mixed coordinate systems.
Hotplug may briefly restore that fallback until the new metadata is complete.
Integer backing/buffer scale still comes from wl_output.scale.

## Version and lifetime rules

- Bind the factory up to version 3. Attach outputs whether the factory or core
  output is announced first.
- For a core-v1 output, a v3 factory cannot provide a usable done boundary.
  Bind a separate real v2 factory; typed new_id inherits its server-side version.
- v3 logical properties publish with core wl_output.done; deprecated logical done
  is ignored. Older logical done publishes logical state without committing a
  pending core batch, and core done does not commit legacy logical state.
- Destroy logical children before removing their output. Factory removal clears
  factory bindings/name while preserving extant children. Reannouncement attaches
  only outputs that lack a child.

## Fixtures and final evidence

Build the Objective-C fixtures as plain-arm64 AppKit programs. Run only in fresh
private prefixes with this backend and installed frameworks.

`logicaltest.m`: **16 checks, zero failures** using actual backend classes and
production callback/readers on a disconnected fixture model. Covers independent
legacy/core batches, v3 done behavior, complete-set fallback, negative/nonzero
anchors, overlap, logical sizes differing from mode/scale, invalid size retention,
one-property updates, extreme coordinates and independent backing scales.
Clearing the synthetic model tests anchor selection, not native object destruction.

`logical-server.c` is a minimal private native server for the no-window
`logical-probe.m`. Generate server headers/private code from xdg-output and
xdg-shell XML as `xdg-output-server.h`/`xdg-output-code.c` and
`xdg-shell-server.h`/`xdg-shell-code.c`; compile with libwayland-server. Server
arguments are factory version, core output version, and reversed registry order.
Set EXPECTED_SCALE=1 for core-v1, otherwise 2, on the probe.

Six initial real-wire cases pass: (3,2,0), (3,2,1), (3,1,0), (3,1,1), (2,2,1),
(1,1,0). The server reports actual child versions; the runner requires exactly
one expected child and zero failures, correct client frame/scale, and a live
server before cleanup. The core-v1/v3 cases observe a real v2 factory binding.

For (3,1,1), an additional `lifecycle` server argument and PROBE_LIFECYCLE=1
remove the factory, update the retained child, reannounce the factory and add a
second core-v1 output. The app sees the retained update and exact two-output
frames; server logs exactly two children, two fresh v3 and two v2 bindings, and
zero failures. This verifies fresh bindings, not request-to-factory generation
identity; the server does not track that latter association.

`logical-live.m` on private Sway, Xwayland disabled, two headless outputs:
**10 topology/window-scale checkpoints pass**. Start 1280x800 at (200,300) and
1000x700 at (-600,-400); move the second to (-300,-200), rotate/scale it 90/2;
change the first to 1200x900 at compositor scale1.5. Then disable/re-enable
outputs, change the second back to normal/1, and remove/restore all outputs.
Compare reported frames with actual Sway output.rect values transformed around
any valid first-screen anchor. Explicitly center the test window on the intended
output for each integer buffer-scale assertion. App exits0, prefix cleanup clean.

The PR107 baseline fails the first topology checkpoint by reporting its synthetic
horizontal arrangement. Its shutdown is clean; later baseline stages are not run.

Candidate backend SHA256:
`1fad727fe33d2f1e4d331379c6070193ab197e5b4ca42c3952a6be129690ffd1`.
Private build and 38-function fixed-arity ABI audit pass. Evidence under
`darling-gui/privbuild/wayland/logical/`: `run-dispatch-reviewed/`,
`run-native-centered/`, `run-protocol-*/`, `run-native-baseline/`, final-results.json.
The earlier `run-native`, `run-native-ipc`, and `run-native-placed` harness attempts
are excluded: negative swaymsg arguments lacked `--`, or window placement/migration
was incorrectly inferred. Each failed prefix was shut down before another run.
Earlier dispatch14/0 is superseded by the explicit two-output backing-scale checks.

Fresh Astra source/fixture review closed after strengthening child-record counts,
server-liveness and independent scale assertions. No installed files, user
prefixes, desktop compositor, Apple apps or PAC settings were changed.

## Limits

This establishes logical topology, including a compositor's fractional layout.
It does not implement fractional-scale buffer rendering. Window global positions
remain virtual; xdg-output does not reveal actual toplevel placement. Stable
CoreGraphics IDs, primary-screen selection and work-area reservations are absent.
Pending-event destruction races, physical monitors and cursor/drag-icon rendering
are not newly established by this fixture set.
