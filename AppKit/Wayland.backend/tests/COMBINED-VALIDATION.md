# Combined Wayland milestone validation

Private integration joins the published DnD stack through `c30f2cd0` (PR105),
physical input `5482e3a2` (PR99), and EGL subwindows `38c0008` (PR98). Merge
`65fd55a5` preserves both timestamped clicks and retained first-press drag
bookkeeping; `461d57a6` adds EGL without dropping protocol/dispatcher entries.
No implementation was cherry-picked or rewritten for these tests.

`integrationtest.m` is a plain-arm64 AppKit fixture with two windows, a 40x40
source GL child and a 300x220 GL child covering the entire drop destination.
Both render magenta repeatedly; dragging uses a yellow 32x24 image. The local-only
payload must reach the parent receiver with the original source identity and
coordinates inside its content bounds. This tests bounds, not exact coordinate
conversion. Separate draw counters must increase for both views between each
begin/end callback.

## Runtime gates

Use private Sway with Xwayland disabled, source at (100,100), target at (600,100),
initial output 1280x800 scale1. Keep a virtual pointer present. Inject down at
(200,180), wait four seconds, move to (700,180), then release.

- `COMBINED_MODE=normal`: parent receives the drop through the EGL child's empty
  input region; exact bytes/source and a single success callback.
- `modifier`: after MODIFIER_GATE_READY, inject left Shift down, right Shift down,
  left up, right up. The original mouse event must still authorize one drag after
  all four exact physical flag transitions.
- `hide`: timer hides the EGL origin during its first drag. Require cancellation,
  stale consumed-event rejection while hidden and after remapping, then NEXT_READY.
  A second fresh press/drag must succeed.
- `hidepress`: hide/remap before any drag consumes the initial press. Require the
  unconsumed stale event to be rejected, then a fresh second press/drag to succeed.
- `scale`: after BEGAN, capture at1x; change output mode to2560x1600 and scale2,
  leaving logical dimensions1280x800; capture again while the drag is active.

All five reviewed runs exit0, report RESULT failures=0, shut down their fresh
prefixes successfully and leave no owned process. Presented-pixel checks compare
original compositor captures: magenta67600 at1x /270400 at2x; yellow768 at1x /3072
at2x. Eight exact color-area assertions pass across normal, modifier and scale
captures. This does not test fractional scale or multiple outputs.

## Explicit private composition

| Artifact | SHA256 |
| --- | --- |
| Combined Wayland backend | `6686a887ef9c6ffdf505a9cbe7f22eed3bff7e5aee37b252eb23d024d2cfe4d9` |
| Frozen M4 OpenGL | `e1226c5a90a7ba8335dfa7e80586e68cbf218f6fe63ced335da6069402f0086b` |
| Frozen M4 QuartzCore | `4bb6e4839a8f407874058029e58424899e694f210134463552d3cda29cc18780` |
| Frozen M4 AppKit | `ae3ab1a335afdd79ccf62da573e4808808e50100d92ec09a98c1ae1a405258f3` |
| Onyx resampling candidate | `fd7d71c1cb69efe0142cba3fbee28ead748adcf854788c146659072c84c53dee` |

Each candidate is hash-checked and copied only into a fresh private prefix;
Onyx belongs under `System/Library/PrivateFrameworks`. The initial exploratory
normal run copied it under Frameworks instead and therefore used installed Onyx;
it is preserved and excluded from the final composition evidence. Earlier
fixture passes preceded stronger per-view rendering and remapped-press assertions;
final claims use only `run-*-reviewed` results.

Evidence: `darling-gui/privbuild/wayland/combined/run-{normal,modifier,hide,hidepress,
scale}-reviewed/`, `pixels.json` and `final-results.json`. Logs include explicit
assertions; captures remain unmodified. The private build/ABI audit passes with
38 fixed-arity native entry points and no direct Wayland/XKB imports.

Fresh Astra review checked both conflict resolutions and semantic auto-merges,
then required stronger runtime assertions. Revised source and logs were reviewed;
no integration blocker found. These plain-arm64 checks do not establish an
installed baseline or new Apple-app readiness. No PAC setting, user prefix,
encrypted volume or installed mutation was involved.
