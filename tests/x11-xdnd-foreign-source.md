Regression test for accepting an XDND drop from a source that follows only the public
protocol, as file managers do. UNRUN: written without a build or an X server.

`X11DraggingManager -handleEnter:` used to refuse every `XdndEnter` unless the source window
carried an `XdndSelection` window property naming the selection to convert. That property is
this backend's own convention and is not in the specification, so a drop from Nautilus, Dolphin
or any other conforming source was ignored: no `XdndStatus` was ever sent. The target now
converts the `XdndSelection` selection itself unless the source publishes that property.

`x11-xdnd-foreign-source.m` (guest, Mach-O) opens a window "xdnd-target" whose view reads
`NSFilenamesPboardType` in `performDragOperation:`. `x11-xdnd-foreign-source-helper.c` (host,
Xlib) is a version 5 source with no `XdndSelection` or per-action window properties; it lists
four types in `XdndTypeList` (`XdndEnter` bit 0 set), requests `XdndActionMove` in
`XdndPosition` `data.l[4]` (the guest view only returns copy, so the target must answer copy), owns the `XdndSelection` selection and serves `text/uri-list`.

## Before and after

Before the fix the helper gets only `XdndStatus` replies with accept clear and exits 5, and the guest fails with
"performDragOperation: never ran". After the fix the status accepts with the copy action
(an atom in `data.l[4]`, not a bit mask), `XdndFinished` reports the drop performed, the
guest receives `/Volumes/SystemRoot/xdnd-probe/a b.txt` and `/Volumes/SystemRoot/xdnd-probe/two.txt` (the decoder maps host paths under that prefix), and both exit 0.

## Command (builder)

    export DPREFIX=$HOME/.local/share/agent-tmp/xdnd-prefix
    export OUT=$HOME/.local/share/agent-tmp/xdnd-out; mkdir -p $OUT
    flock -w 1800 /tmp/agent-locks/darling-heavy-build.lock bash -c '
      darling shell clang /Volumes/SystemRoot$PWD/tests/x11-xdnd-foreign-source.m \
          -o /Volumes/SystemRoot$OUT/xdnd-foreign -framework AppKit -framework Foundation &&
      tests/x11-guest-helper.sh tests/x11-xdnd-foreign-source-helper.c /Volumes/SystemRoot$OUT/xdnd-foreign'

Use an AppKit built from this branch. Needs the action-atom commit below it in the stack; without
the copy fallback in the drop session the helper exits 5 (copy-only receiver refused for a move request).

Source of behaviour: the XDND specification, https://www.freedesktop.org/wiki/Specifications/XDND/
(rung 3, public documentation); no Apple binary inspected.
