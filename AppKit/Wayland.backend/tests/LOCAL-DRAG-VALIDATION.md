# Local-only Wayland drags

A source allowing local COPY/MOVE but no representable external operation used
to return without starting. It now supports same-process drops without exporting
its Cocoa payload. Local filenames remain original pasteboard bytes; they need
not be host-exportable paths. This does not implement general guest-file export.

## Transport and lifetime

A real `wl_data_source` advertises only an opaque, per-drag random marker MIME.
Every native SEND closes its descriptor without writing bytes. User data and
Cocoa type names stay in an immutable, bounded (16 MiB) process-local snapshot;
DELETE control targets are excluded. A native source is needed for cancellation
and completion notifications: source-less `start_drag` has no source object to
notify when release occurs outside the initiating client's surfaces.

Private access requires an actually started local-only drag, exact singleton
marker match, current generation and exact destination session identity. Sessions
retain the manager and their immutable snapshot. Pre-drop leave revokes access
synchronously before deferred application callbacks; normal drop-then-leave
preserves the queued perform path. Old session reads fail even if their objects
remain retained. Key callbacks recheck mapped window/session permission.

A local success record is written only after validated successful perform. Source
completion requires native drop/finish and an exact matching local action. An
external client finishing the marker cannot produce source success, including
MOVE. An external client can see marker/action metadata and could display an
acceptance cursor; it receives no payload. The random marker rejects stale offers,
not a malicious compositor: compositor/seat ordering is trusted.

This implements local COPY/MOVE when no external COPY/MOVE is available. It does
not yet independently negotiate different local/external action sets for a source
that permits both, add LINK/ASK, slide-back, promises or modern dragging sessions.

## Reproduction

Use `outgoingtest.m` on a private compositor with Xwayland disabled. Inject a press
on the green source, move to the blue same-app destination, and release. Set
`LOCAL_ONLY=1 LOCAL_DROP=1`; add `SOURCE_MOVE=1 TARGET_MOVE=1 EXPECT_MOVE=1` for MOVE.
Existing fixture timers and terminal-callback assertions remain active.

Additional modes:

- `LOCAL_FILES=1`: original guest-only filename plist, exact bytes and semantic
  array equality; no file is opened or modified.
- `LOCAL_OPAQUE=1`: opaque Cocoa type, exact bytes. Local-only fixtures add DELETE
  and check it is absent from the receiving pasteboard.
- `OLD_READ=1`: enter destination, move back to source, re-enter destination;
  old retained pasteboard must deny reads while new session succeeds.
- `TWO_DRAGS=1`: after NEXT_READY, start a second drag and release in blank space;
  prior generation reads fail, and only the first drag reports success.
- `LIVE_TEARDOWN=1 EXPECT_CANCEL=1`: simulate display releasing manager ownership
  before retained-session cleanup. This exercises the reviewed ownership-ordering
  defect, not full NSDisplay destruction. Require both MANAGER_OWNER_RELEASED and
  RETAINED_SESSION_CLEANED.
- `PREPARE_UNMAP=1 EXPECT_CANCEL=1`: destination disappears during prepare.
- `NESTED_DROP=1 EXPECT_CANCEL=1`: destination pumps drop before returning refusal.

`private-drag-target.c` is an adversarial native Linux receiver. Generate
`xdg-shell-client.h` and `xdg-shell.c` with wayland-scanner, compile/link against
wayland-client, and use it instead of the GTK target. With
`LOCAL_ONLY=1 SOURCE_MOVE=1 EXPECT_CANCEL=1`, release over this receiver. It verifies
one private MIME, accepts MOVE, requests data, asserts zero-byte EOF, then sends
finish anyway. The source must report NONE. Ordinary GTK rejection is a separate
gate and cannot substitute for this adversarial receive/finish test.

## Evidence, 2026-09-16

Thirteen final private native-compositor cases PASS: COPY, MOVE, exact guest
filename/opaque bytes, adversarial external MOVE, ordinary external rejection,
blank-space cancellation, stale-session replacement, sequential generation,
manager ownership teardown, prepare-unmap, nested refusal and public COPY
regression. All app exits0, successful prefix shutdowns, no live owned processes.

Evidence: `darling-gui/privbuild/wayland/local-drag/final-results.json` and the
referenced run directories contain logs, original captures and cleanup statuses.
Final backend SHA256:
`f1c6bd431c452b004614e5be33ff81e09343034fe28acf3837895a796be51048`.
Earlier GTK adversarial attempt only rejected the marker; its failing harness
assertion is preserved and excluded from final receive/finish evidence.

Private compile and native ABI audit pass: 35 fixed-arity functions, no direct
Wayland/XKB imports. Fresh Astra adversarial review found the retained-session
manager lifetime hazard; corrected, discussed and tested. Reviewer inspected
source, not execution. No Apple apps, PAC overrides, installed changes, user
prefixes or encrypted volumes were used.
