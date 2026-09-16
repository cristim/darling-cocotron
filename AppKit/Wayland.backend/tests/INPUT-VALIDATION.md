# Wayland input regression

## Original aggregate-input fixture (PR99)

`inputtest.m` is a plain-arm64 AppKit fixture. Build it like `waylandtest.m`,
select this backend using `DARLING_APPKIT_BACKEND=wayland`, and run it against a
private compositor with Xwayland disabled. It logs generated AppKit events and
exits after 18 seconds. It consumes input in `sendEvent:`; it does not validate
responder-chain delivery.

Inject the following into its content area:

1. Two left clicks at the same point, 60 ms apart: down/up counts `1,1,2,2`.
2. Move 50 logical pixels, then left-click immediately: counts `1,1`.
3. Immediately right-click at that point: counts `1,1`.
4. Press/release Shift, Control, Alt and Logo: `NSFlagsChanged` (`type=12`)
   with masks `131072`, `262144`, `524288`, `1048576`, each followed by zero.
5. Focus an independent native client while leaving the pointer above the test
   window. Hold Shift: no keyboard event may reach the unfocused test app.
   Focus the test app while Shift remains held: Shift flags must synchronize,
   followed by zero on release.

The physical key identity is only known when a preceding `wl_keyboard.key`
identifies it. Virtual keyboard mask changes and focus synchronization use
`keyCode=0xFFFF` (unknown). The compositor's modifiers event is authoritative.
The original PR99 change emits **aggregate modifier transitions**; pressing another side of
an already-held modifier need not change the aggregate mask and is not emitted
as a separate event. The follow-up below adds independent left/right state.

### Original recorded validation, 2026-09-16

Isolated headless Sway, installed isolation-safe Darling launcher, fresh short
prefixes, serialized test locks, no Apple apps or PAC overrides:

- Historical backend: click counts incorrectly continue `1,2,3,4`; no modifier
  events for the four injected mask transitions.
- Candidate: click counts `1,2,1,1`; all four flags and releases correct.
- Final candidate: focus exclusion and held-Shift synchronization pass.
- All three fixtures exit zero; shutdown succeeds; no owned processes remain.
- Private backend compile and native-ABI audit pass (35 fixed-arity functions,
  no direct Wayland/XKB imports).
- Fresh Astra adversarial review identified stale button/count state after
  focus loss; the implementation clears both on pointer leave/window unmap.

Durable evidence: `darling-gui/privbuild/wayland/input/run-baseline/`,
`run-fixed/`, `run-focus/` (app logs, original captures and status files).
Final tested backend SHA256:
`4a9a3592e83ff6bf2f60e5d7ef098320202866f781226364ee2980e3b8bc2720`.
No explicit runtime coverage is claimed for timestamp wrap, every physical
modifier keycode, Caps Lock, or disappearing-window chords; those paths received
source review.


## Left/right modifier follow-up

A physical key transition now produces `NSFlagsChanged` even when its aggregate
mask remains unchanged. The keyCode records the modifier's identity at press
time; its release keeps that identity through layout and keymap changes.
Device-dependent flags use the IOKit `NX_DEVICE*KEYMASK` values for the left/right
Shift, Control, Option and Command keys. High aggregate bits and Caps Lock state
remain compositor-authoritative. Mask-only changes still have keyCode `0xFFFF`.

For example, left Shift down, right Shift down, left up, right up must produce:

| keyCode | flags |
| --- | --- |
| 56 | 131074 (Shift + left) |
| 60 | 131078 (Shift + both) |
| 56 | 131076 (Shift + right) |
| 60 | 0 |

The pending transition resolves on the following modifiers event, before the
next keyboard/pointer input, or via `wl_display.sync` when idle. **The fallback
assumes the compositor queues a key's resulting modifiers before processing the
client's sync request or subsequent input.** Sync drains already-queued events;
it does not fence future input. Forced socket fragmentation was not tested.

### Fixtures

`modifier-keyboard.c` is a native Linux virtual-keyboard driver. Generate
`virtual-keyboard-client.h` and `virtual-keyboard.c` with `wayland-scanner` from
`virtual-keyboard-unstable-v1.xml`, then compile/link against wayland-client and
xkbcommon. It installs a us,de keymap and accepts `down EVDEV`, `up EVDEV`, and
`sleep MILLISECONDS` pairs. It sends authoritative XKB masks only when changed.
An optional `KEYMAP_FILE` writes its generated map to an exclusively created
fixture file. Use only a private compositor; this injects physical keyboard input.

Run `inputtest.m`, focus its window, then inject four-step overlap sequences
for evdev pairs `(42,54)`, `(29,97)`, `(56,100)`, `(125,126)`, 150 ms apart.
These are Shift, Control, Option and Command. Each needs four distinct events,
with the matching side bits. A subsequent A press/release while both Shifts are
held must follow the two flags events and retain both side bits.

`modifier-dispatch.m` exercises the actual loaded backend and its real sync
callbacks. Build like `inputtest.m`; start the native keyboard with `sleep 10000`
and a private `KEYMAP_FILE` before its four-second timer fires. Give the Darling
fixture that same owned file via its `/Volumes/SystemRoot` path. It temporarily
records this display's `postEvent:atStart:` calls while invoking protocol handlers;
it does not substitute modifier logic. It validates delayed-mask handling, idle
sync delivery, keyboard/pointer ordering, held-key focus synchronization, Caps
Lock, us/de group changes, and pending-callback cancellation on leave, same-map
replacement, window unmap and keyboard-device loss. Same-map replacement tests
cancellation/state retention, not a remapping during a held key. It exits zero
only when all assertions pass.

### Follow-up validation, 2026-09-16

- Previous PR99 backend: only 8 physical modifier events for the 16 overlap
  transitions, confirming the regression.
- Candidate: all 16 exact keycodes and sided masks match; ordinary A events keep
  both Shift bits. Native fixture exits zero.
- Actual-backend dispatch fixture: 17 checks, zero failures.
- Both locks held through every private-prefix shutdown; all exit zero and
  report no live owned handles. No Apple apps, PAC settings or installed changes.
- Private build and ABI audit pass; 35 fixed-arity native entry points and no
  direct Wayland/XKB imports.
- Fresh Astra review identified cross-device ordering, keymap identity and
  fixture failure-handling issues; all corrected. Reviewer inspected source;
  execution evidence is from the owning session.

Durable evidence: `darling-gui/privbuild/wayland/modifiers/run-baseline/`,
`run-fixed/`, `run-dispatch/`, `run-dispatch-final/`.
Tested backend SHA256:
`b4a12330cb89601b8a45e94505d0ddc0ca74016b885ed702a63028526308a198`.
