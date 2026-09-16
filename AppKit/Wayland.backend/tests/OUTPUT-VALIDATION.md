# Core output state and rotated screens

`wl_output` v2 batches now publish mode lists, current mode, transform and scale
at `done`. All screen/mode/scale readers use that committed state. Version 1 has
no `done`, so each event updates the state and invalidates screen caches. Its
multi-event updates cannot be atomic. Raw mode dictionaries retain physical,
untransformed pixel dimensions; screen frames apply rotation and floating-point
scale division. Transforms 1/3/5/7 swap width and height.

## Direct-dispatch regression

Build `outputtest.m` as a plain-arm64 AppKit executable. Run with this private
backend in a disposable prefix and private native compositor. The fixture loads
the actual backend classes, allocates a disconnected display/output model and
calls the production event handler and readers. It creates no synthetic native
proxies and does not replace the output algorithm.

Final result: **23 checks, zero failures**. Checks cover pending initial mode,
every state reader before `done`, a forced screen-cache rebuild during a batch,
copied mode-array isolation, all eight transforms, odd dimensions at scale 2,
scale-only/transform-only later batches, invalid-mode/transform preservation,
and a mode event replacing a cached v1 fallback. Scales are initialized directly
like registry binding; the v1 test sends no unsupported scale event.

Clearing the synthetic model tests empty-screen fallback only. It does not test
registry removal before initial `done`. Native removal is covered separately.

## Native two-output regression

Build `outputlive.m`. Use isolated Sway with Xwayland disabled,
`WLR_BACKENDS=headless`, `WLR_HEADLESS_OUTPUTS=2`, a private runtime directory and
virtual pointer. Start HEADLESS-1 at 1280x800, position 0,0; HEADLESS-2 at 1000x700,
position 1280,0. Float the fixture at 100,100 without compositor borders.
Its bounded 24-second run reports each changed screen set and window buffer scale.

Using private `swaymsg`, check these transitions in order (screen enumeration
order is unspecified; compare the multiset of width/height/scale):

1. Two outputs: 1280x800@1 and 1000x700@1, window scale 1.
2. HEADLESS-2 transform 90, scale 2: 350x500@2, first output/window unchanged.
3. HEADLESS-1 mode 2560x1600, scale 2: 1280x800@2, window scale 2.
4. Disable HEADLESS-1: only 350x500@2 remains, window scale 2.
5. Enable HEADLESS-1: both outputs return, window scale 2.
6. Disable HEADLESS-2: only 1280x800@2 remains.
7. Disable HEADLESS-1: 1920x1080@1 fallback and window scale 1.
8. Enable HEADLESS-1: 1280x800@2 returns, window scale 2.

All eight checkpoints pass; app exits 0 and prefix shutdown is clean. This checks
actual registry removal/reappearance and window-scale propagation. It does not
check drag-icon rendering, arbitrary physical monitors or global output positions.

The pre-fix combined backend fails checkpoint 2, reporting 500x350@2 instead of
350x500@2. It is shut down at that first failure; no later baseline result claimed.

## Provenance and limits

Candidate backend SHA256:
`60bf01093d24e5fb6275ebc30fdb0b09a20d7cb70201a70db6d523227bf8a92d`.
Baseline: `6686a887ef9c6ffdf505a9cbe7f22eed3bff7e5aee37b252eb23d024d2cfe4d9`.
Private build and fixed-arity ABI audit pass. Only the backend is replaced in the
fresh prefixes; AppKit/frameworks use the installed baseline. No Apple/PAC tests,
installed mutations, user-prefix or desktop access.

Evidence: `darling-gui/privbuild/wayland/outputs/run-dispatch-reviewed/`,
`run-native-order-independent/`, `run-native-baseline/`. All cleanup inventories
are empty. The initial `run-native/` assumed enumeration order and is excluded;
`run-dispatch/` predates the strengthened cache assertions and is superseded.
Fresh Astra review caught the test initialization/cache gaps; both were corrected
before the final run. Source review found no remaining blocker.

Screen origins remain a synthetic left-to-right arrangement. xdg-output logical
positions and fractional-scale protocol support remain follow-ups. Display IDs
remain positional: stable IDs require coordinated changes to CoreGraphics, which
currently enumerates IDs as index+1 and resolves several APIs with displayId-1.
Changing NSScreen IDs alone would make the APIs disagree; no such change ships.
