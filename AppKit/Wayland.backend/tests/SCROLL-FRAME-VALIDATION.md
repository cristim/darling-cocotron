# Wayland scroll-frame validation

## Scope

Wayland seat version 5 groups pointer updates with `wl_pointer.frame`. The
backend previously negotiated that version but posted every `axis` update as a
separate `NSScrollWheel` event and ignored `frame`. The focused change retains
axis deltas until the frame boundary and posts one event containing both axes.
Seats older than version 5 keep immediate axis delivery.

This reduces AppKit event dispatch and redraw work only when a compositor sends
multiple axis updates in one pointer frame. A frame containing one vertical
axis update still produces one event. Window presentation still copies the
complete Onyx2D surface into a `wl_shm` buffer, so this is not a partial-damage
or zero-copy optimization.

## Static and compile checks

From the Cocotron checkout:

```sh
python3 AppKit/Wayland.backend/tests/scroll-frame-wire.py
```

The guard checks the version-5 frame opcode, runtime protocol-name validation,
seat version cap, accumulation/frame dispatch, and the pre-version-5 fallback.
It reports seven checks and zero failures.

`WaylandDisplay.m`, `WaylandLibrary.m`, and `scroll-frame-dispatch.m` also
compile as arm64 Mach-O objects with Darling's existing AppKit compiler flags.
Only the existing TargetConditionals macro warnings (and the existing
WaylandDisplay designated-initializer warning) are emitted.

## Private runtime fixture

Build `scroll-frame-dispatch.m` like the existing `modifier-dispatch.m` fixture
and run it only against an isolated private compositor and disposable Darling
profile. It calls the real backend's pointer protocol entry point and captures
posted AppKit events. Expected checks are:

- horizontal and vertical axis updates post nothing before `frame`;
- one frame posts one event with both deltas;
- repeated updates on one axis accumulate into that event;
- an empty frame posts no event;
- a pending scroll is posted before an overtaking button event;
- pre-v5 axis delivery remains immediate; and
- pointer leave, window unmap, and pointer capability loss discard an
  unfinished frame, while capability reacquisition resumes framed scrolling.

No live desktop viewer or shared installed profile is required. Runtime timing
must compare the same input stream before and after this change; event-count
improvement should only be claimed for frames that contain multiple axis
updates. Full-window copy cost must be measured and reported separately.
