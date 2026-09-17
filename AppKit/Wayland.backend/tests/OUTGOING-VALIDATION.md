# Outgoing Wayland copy drops

`outgoingtest.m` is a plain-arm64 AppKit source. `outgoing-target.c` is a native
GTK3 destination (build with `pkg-config --cflags --libs gtk+-3.0`). Run both on
an isolated Wayland compositor with Xwayland disabled, keeping source and target
windows at distinct positions. Inject a pointer press on the green source,
move to the target and release. The payload is UTF-8 `Darling outgoing — café`
(26 bytes). The fixture requires one terminal callback and a timer firing while
`dragImage:` is waiting.

Modes:

| App environment | Destination | Expected result |
| --- | --- | --- |
| none | GTK target | exact 26 bytes, one COPY callback, return/exit0 |
| `EXPECT_CANCEL=1` | release outside all windows | one NONE callback, return/exit0 |
| `LOCAL_DROP=1` | blue same-app target | exact data and original source identity, COPY |
| `EXPECT_CANCEL=1` | GTK with `HOLD_DROP=1` | data arrives; no finish; bounded NONE callback |
| `LOCAL_DROP=1 LOCAL_REJECT=1 EXPECT_CANCEL=1` | same-app target | local source mask forbids delivery; NONE |
| `INVALID_PROVIDER=1` | any | lazy provider unmaps origin; no begin/end callback, return0 |

For same-app tests, move the GTK control away rather than overlapping targets.

## Implementation boundaries

- One new v3 data source per drag, independent of clipboard source. COPY/MOVE
  negotiation is covered in DRAG-ACTIONS-VALIDATION.md.
- The first pointer press establishing the grab supplies the serial. Recheck
  origin/event/serial after lazy application callbacks; consume eligibility once.
- Immutable snapshot, at most16MiB total payload; existing bounded off-thread
  writer handles pipe backpressure. Post-drop completion has a10-second deadline.
- Run-loop sources/timers are pumped nonblocking, then the native display fd is
  polled for at most10ms. Timed nested Foundation and Core Foundation waits were
  observed not returning within20s in this Darling runtime; this local loop keeps
  completion bounded without altering shared runtime code.
- Completion is immutable and emitted once outside native dispatch, after active
  state clears. Incoming same-app sessions retain the original source and local
  operation permission.
- Drag icons are covered in DRAG-ICON-VALIDATION.md. No slide-back animation.
  Local-only COPY/MOVE support is covered in LOCAL-DRAG-VALIDATION.md.
  File/promise conversion and modern dragging-session APIs remain
  follow-ups. Core Wayland provides no global drop coordinates; endedAt currently
  uses the original virtual location. This is not full drag-and-drop parity.

## Recorded evidence, 2026-09-16

Final candidate SHA256:
`0a4d9439072d251547466f5be789fd584a240a0de681c2440af6a5cfbd28308f`.

Six final native-compositor cases PASS, each app exit0, successful prefix
shutdown, no owned processes left. All five started drags fire a timer and emit
one terminal callback; the invalid-provider case emits neither callback.
Private arm64 compilation and native ABI audit pass (35 fixed-arity functions,
no direct Wayland/XKB imports). Fresh Astra adversarial review closed after
iterative serial, lifetime, completion, local-mask and event-loop corrections.

Durable evidence: `darling-gui/privbuild/wayland/outgoing/run-{accept,cancel,local,
timeout,reject,provider}-final/`. Each contains logs, original compositor captures,
backend hash, prefix and cleanup inventory. Earlier overlapping-target and timed
run-loop failures remain preserved and are excluded from the final passing set.
Chord presses, right-button starts, disappearing-origin-after-start, allocation
failure and clock failure received source review but no runtime success claim.
No Apple apps, PAC overrides, installed library changes or user prefixes used.

Host-backed filename/URI conversion is covered in FILE-URI-VALIDATION.md; guest-only
export and promises remain unsupported.
