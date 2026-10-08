# Wayland editor shortcut probe

Build `appkit-editor-shortcuts-wayland.m` as a plain arm64 AppKit executable and
run it with `DARLING_APPKIT_BACKEND=wayland` in a private Darling prefix and a
private Wayland compositor. The window starts with `abc` and a caret after `a`.
It logs the real key flags, dispatched command, selection, text, and clipboard.

To reproduce sided modifier events, send both the physical key transition and
the aggregate modifier mask. `wtype -M shift` alone omits the physical Shift
bit and does not reproduce the binding failure. Keep each `wtype` client alive
briefly so the compositor delivers its queued events:

```sh
wtype -s 300 -P Shift_L -M shift -s 200 -k Right -s 200 -m shift -p Shift_L -s 200
wtype -s 300 -P Super_L -M logo -s 200 -k c -s 200 -m logo -p Super_L -s 200
wtype -s 300 -k Right -s 200
wtype -s 300 -P Super_L -M logo -s 200 -k v -s 200 -m logo -p Super_L -s 200
```

Run each command with the private compositor's `XDG_RUNTIME_DIR` and
`WAYLAND_DISPLAY`, allowing the editor to process it before the next command.
Expected states are `range=1,1 text=abc`, then `clipboard=b`, then
`range=2,0`, then `text=abbc`. For Shift+Left, start at the end of the text and
use `Left` in the same physical Shift sequence. The selected glyph should be
drawn inside its highlight.

`appkit-key-binding-device-flags.m` also tests the binding and `NSTextView`
behavior without compositor input. Before the fixes, sided Shift+Right inserts
a space; with only the binding fixed, Shift+Left underflows the selection
length. Both tests should pass with the candidate AppKit.

## Expanded X11 and Wayland checks

The same probe also runs with `DARLING_APPKIT_BACKEND=x11` on a dedicated Xvfb
server. Enable `DYLD_FRAMEWORK_PATH` to point at a private candidate framework;
staging into a prefix's `/System` alone may still load the installed framework.
Check `DYLD_PRINT_LIBRARIES=1` output to verify the candidate actually loaded.
Focus the probe on the private display before running:

```sh
python3 tests/appkit-editor-shortcuts.py x11 /absolute/path/to/probe.log
python3 tests/appkit-editor-shortcuts.py wayland /absolute/path/to/probe.log
```

Set `DISPLAY` for X11, or `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY` for Wayland.
Run each backend separately. The script sends actual XTest/Wayland virtual-keyboard
input and asserts 42 text, selection, and clipboard states. It covers:

- Ctrl+A/C/X/V; Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y.
- Left/Right, Shift+Left/Right, Ctrl+Left/Right, Ctrl+Shift+Left/Right.
- Up/Down, Shift+Up/Down, Ctrl+Up/Down, Ctrl+Shift+Up/Down.
- Home/End, Shift+Home, Ctrl+Home/End, Command+Home/End and their Shift variants.
- Alt+Left and Alt+Shift+Right, which are the configured line-navigation bindings.
- Reversing a selection across its anchor, empty text after Cut, and multiline EOF.

Ctrl+Home/End are configured to scroll without moving the caret. Command+Home/End
move to document boundaries. Home/End use paragraph boundaries. These are the
existing Cocotron bindings, rather than a wholesale switch to Linux conventions.

`appkit-key-binding-device-flags.m` checks both aggregate and device modifier bits,
Ctrl word/paragraph and undo bindings, document-selection reversal, and editor
copy/paste. `appkit-menu-shortcut-modifiers.m` checks that Command+Shift+Z selects
Redo rather than Undo, including uppercase equivalents from older nibs.

### Failures reproduced before correction

1. Physical Wayland Shift+Right missed the binding and inserted a space.
2. After binding normalization alone, Shift+Left underflowed the selection length.
3. Selected glyph drawing advanced by a glyph before drawing the preceding run.
4. Ctrl word-navigation and undo/redo combinations were absent from standard bindings.
5. X11 copy raised `Cannot set nil objects nor nil keys` when declaring eager
   clipboard types with a nil owner.
6. Wayland's lowercase Ctrl+Shift+Z key string missed the uppercase redo binding.
7. Up at EOF used the unclamped index to construct its line range; the input
   assertion expected caret 7 but got 8 for `abc\ndef\nghi`.
8. Menu matching ignored Shift: Command+Shift+Z performed another Undo.
9. Reversing Command+Shift+Home/End used a range edge instead of the selection anchor.

The binding, menu, EOF input, and document-reversal tests were observed failing
before their fixes. Private logs and screenshots are under `.private-test/`.

### Isolation and limits

The tested apps are private copies of TextEdit and Stickies. All prefixes,
frameworks, display servers, logs, and screenshots are private. No shared build
configuration, object files, live prefixes, or other developers' source trees
were changed. No Apple implementation source was used.

The candidate is a focused build: five changed AppKit sources and X11Pasteboard
are compiled from this checkout, with unrelated existing objects and SDK headers
read from `/home/cristi/src/darling/build`. A full clean framework build remains
unverified. The installed Wayland backend was used for actual event generation;
both backend key-string forms are covered by the menu/binding regressions.

This matrix covers the named editors and default keyboard layout. It does not
establish correctness for every app, IME, layout, bidirectional text, wrapped
proportional text, PageUp/PageDown, or every shortcut in StandardKeyBindings.
Clipboard persistence after the owner exits is unverified; a short-lived owner
stalled the X11 observer during concurrent test runs, so clipboard tests must run
serially with persistent app owners.

### Source changes

| File | Change |
| --- | --- |
| `NSKeyboardBindingManager.m` | Ignore physical modifier side bits during binding lookup. |
| `StandardKeyBindings.keybindings` | Add Ctrl word/paragraph navigation and Shift selection; Ctrl undo/redo, with both shifted Z forms. |
| `NSMenu.m` | Compare Shift and Control as well as Command/Alt; handle uppercase equivalents implying Shift. |
| `NSTextView.m` | Initialize the selection anchor from the caret location; preserve it for document-selection reversal. |
| `NSLayoutManager.m` | Advance glyph widths after drawing each preceding run; clamp EOF before constructing its line range; handle empty text. |
| `X11Pasteboard.m` | Accept nil owners for eagerly written clipboard types. |
| `.gitignore` | Ignore private build/runtime artifacts under `.private-test/`. |

The probe now enables undo and escapes newlines in state logs. The Python input
runner waits for asynchronous state updates and asserts the resulting text,
selection, and clipboard rather than merely checking command dispatch.

### Final verification — 2026-10-08

| Check | X11 (private Xvfb) | Native Wayland (private headless Sway) |
| --- | --- | --- |
| Binding/editor regression, including document reversal and copy/paste | PASS | PASS |
| Menu modifier/Redo regression | PASS | PASS |
| Probe input assertions | 42 PASS | 42 PASS |
| Actual TextEdit and Stickies assertions | 24 PASS | 24 PASS |

The real-app assertions cover Ctrl word selection/copy, paste, cut/paste,
undo/redo, Home/End selection, multiline Up, document-selection reversal,
Command copy/paste/undo/redo, and clipboard transfer in both directions between
the apps. X11 reads the copied text through the separate probe; Wayland reads
`text/plain;charset=utf-8` through `wl-paste`. RTF payloads were also inspected in
prior Wayland runs. The full 42-case navigation matrix is asserted in the probe;
the real apps receive the representative cases above, rather than every probe
combination individually.

Shortcut-only candidate AppKit UUID: `27EA7ABB-B7A6-3722-9F11-3B7781BB3D58`.
Private X11 backend UUID: `F6772C2C-90ED-3AC2-8317-75A12E5BCCE5`.
Actual app dyld logs confirm the private binaries loaded, and native Wayland
logs confirm a compositor connection.

Evidence under `.private-test/`:

- `automation-x11-final.log`, `automation-wayland-final.log`.
- `apps-x11-final.txt`, `apps-wayland-final.txt` and the corresponding private
  `check-apps-*-final.py` automation scripts.
- `binding-test-*-final.log`, `menu-test-*-final.log`.
- Baselines: `editor-baseline3.log`, `extended-regression-red.log`,
  `x11-eager-owner-red.log`, `automation-red.log`, `menu-regression-red.log`,
  `document-selection-red.log`.
- Selected-glyph screenshots: `stickies-selected-crop.png` before correction,
  `stickies-fixed4-selected-crop.png` after correction.

`git diff --check` and Python syntax parsing passed. Builds completed with
pre-existing macro and duplicate NSStringDrawing category warnings. No full
clean framework rebuild or unrelated application suite was run.

## Context-menu follow-up — 2026-10-08

Real private pointer input reproduced a destructive cancellation bug: right-click
selected text, hover Cut, then press Escape. `NSMenuView` marked tracking cancelled
but still returned the highlighted Cut item, so the caller executed it. The probe
changed from `abc` to empty text. The new `appkit-context-menu.m` regression failed
before correction with `cancelling the highlighted context action returned Cut`.

Changes:

- `NSMenuView.m`: return no action when tracking was cancelled, including Escape
  and application deactivation.
- `NSTextView.m`: add a separator only after an actual spelling section; skip
  spelling lookup at EOF/empty text; give the disabled “No Guesses Found” item
  no action; validate Cut/Copy against a nonempty selection and editing/selecting
  permissions, Paste against editability, and Select All against available text.
- `appkit-context-menu.m`: cover both cancellation events, selected/empty menu
  structure, empty-selection validation, and read-only Cut/Paste validation.

| Verification | X11 | Native Wayland |
| --- | --- | --- |
| Context-menu regression | PASS | PASS |
| Actual TextEdit/Stickies pointer and clipboard assertions | 12 PASS | 12 PASS |

Each real app passed Escape preservation, menu Copy, menu Cut deletion, menu
Paste restoration, outside-click preservation, and a further edit/copy proving
it stayed responsive. Menus were inspected visually; the unnecessary leading
separator is gone, and unavailable actions are greyed out. These changes retain
the existing Cocotron menu style.

A process crash was **not reproduced** in these private runs. The cancellation
bug can make selected content disappear, but this is not evidence that it caused
the originally reported crash. No crash fix is claimed without a matching crash
trace. The earlier X11 nil-pasteboard-owner fix also applies to context actions.

An initially missing Wayland clipboard offer was traced to the headless seat
losing its temporary virtual keyboard. With keyboard capability kept present,
context-menu Copy exported normally. No Wayland backend source change was made.

Context candidate AppKit UUID: `D4BB6F4B-730B-366C-A5DC-890EE7D70BC2`.
Actual-app dyld logs confirm this private binary loaded. Evidence:

- `.private-test/context-regression-red.log` and
  `context-regression-{x11,wayland}-green.log`.
- `.private-test/context-{x11,wayland}-actions.log` and corresponding private
  automation scripts, using XTest or a Wayland virtual pointer.
- `.private-test/textedit-context-open.png` (before),
  `TextEdit-context-fixed-menu.png` and `TextEdit-context-x11-menu.png` (after).
- `.private-test/TextEdit-context-*.log` and `Stickies-context-*.log`.

No CoreText, typesetter, font-metric, or bitmap-dimension files were touched.

## Publication on current upstream

The original private runtime results above used base `3326fbfed` and the listed
candidate binaries. The publication commit is rebased onto `ec245a01f`; its
runtime has not been rerun. Upstream already contains the X11 nil-owner guard
and modifier-aware menu dispatch, so the PR retains those implementations and
adds only case normalization for shifted uppercase equivalents. Upstream's
existing Control-Z binding is retained without duplication. Prior runtime
results are evidence for the original candidate, not a full verification of
this rebased source. A full clean build and fresh app runs remain required.

Publication checks: all five edited AppKit Objective-C sources compile against
the available SDK, with `NSEventModifierFlagShift=NSShiftKeyMask` supplied only
for the private NSTextView compile because the installed SDK predates that
upstream constant. This is a compile check, not a new runtime result.
`git diff --check` and the automation script's Python syntax check pass.
