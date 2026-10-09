Regression test for XDND version decoding on the X11 backend. UNRUN: written without a
build or an X server.

`X11DraggingManager -handleEnter:` takes the protocol version from bits 24-31 of
`XdndEnter` `data.l[1]` (bit 0 of that word is the "more than 3 types" flag). It used to
read `data.l[1] & 0xFF`, which is 0 or 1 for a conforming source, so action negotiation
(version 2 and later) never happened and every drag was treated as copy-only.

`x11-xdnd-version.m` (guest, Mach-O) opens a window "xdnd-target" whose view records
`draggingSourceOperationMask` in `draggingEntered:`. `x11-xdnd-version-helper.c` (host,
Xlib) is a version 5 source that advertises only `XdndActionMove` and sends `XdndEnter`
with `5 << 24` in `data.l[1]`, then `XdndPosition` with the move action.

## Before and after

Before the fix the version reads as 0, so the source mask starts as copy; the move the source
requests in `XdndPosition` is ORed in, which makes the guest see copy|move rather than move
and fail with "expected move" (the helper still sees a move status). After the fix the mask is
exactly move and both exit 0 (`PASS: x11-xdnd-version`). Needs the action-atom commit
(`XdndStatus` data.l[4] is an atom) below it in the stack.

## Command (builder)

    export DPREFIX=$HOME/.local/share/agent-tmp/xdnd-prefix
    export OUT=$HOME/.local/share/agent-tmp/xdnd-out; mkdir -p $OUT
    flock -w 1800 /tmp/agent-locks/darling-heavy-build.lock bash -c '
      darling shell clang /Volumes/SystemRoot$PWD/tests/x11-xdnd-version.m \
          -o /Volumes/SystemRoot$OUT/xdnd-version -framework AppKit -framework Foundation &&
      tests/x11-guest-helper.sh tests/x11-xdnd-version-helper.c /Volumes/SystemRoot$OUT/xdnd-version'

Use an AppKit built from this branch. `x11-guest-helper.sh` is the shared driver (same file
as in the x11-xdnd-drop test).

Source of behaviour: the XDND specification, https://www.freedesktop.org/wiki/Specifications/XDND/
(rung 3, public documentation); no Apple binary inspected. Not covered: the "more than 3
types" bit (exercised by the existing drop path only for the 3-type case).
