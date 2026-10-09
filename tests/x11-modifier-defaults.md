Regression test for the primary Control mapping in X11 key events
(`fix/x11-modifier-defaults`). UNRUN: written without a build or an X server.

`x11-modifier-defaults.m` (guest) sets `NSModifierFlagMapping = {LeftControl = Command}`
in its own defaults, opens a window "mod-probe", and checks the `modifierFlags` of four
key-down events. `x11-modifier-defaults-helper.c` (host, Xlib) sends synthetic KeyPress
events for the x key with X states ControlMask, ControlMask|ShiftMask, Mod4Mask, ShiftMask.
Expected flags: Command; Command|Shift; Command; Shift.

## Before and after the fix

Before 70d27c863, `modifierFlagsForState:` maps ControlMask to `NSControlKeyMask`
unconditionally, so the first key reports Control and the guest exits 1 with
"key 0 had flags 0x40000, expected 0x100000". After it, the guest prints
`PASS: x11-modifier-defaults`. The Mod4 and Shift cases guard against the change
disturbing the other flags.

Not covered: the unmapped case (Control stays Control) because the mapping is read per
event and the pair has no channel to change it mid-run; a menu shortcut driven by the
mapped Control (see `menu-injected-runtime.m`); RightControl.

## Command (builder)

Host paths appear in the guest under `/Volumes/SystemRoot`. Use a private prefix
(`DPREFIX`) and an AppKit built from this branch; run the pair under the heavy lock.

    export DPREFIX=$HOME/.local/share/agent-tmp/mod-prefix
    export OUT=$HOME/.local/share/agent-tmp/mod-out; mkdir -p $OUT
    flock -w 1800 /tmp/agent-locks/darling-heavy-build.lock bash -c '
      darling shell clang /Volumes/SystemRoot$PWD/tests/x11-modifier-defaults.m \
          -o /Volumes/SystemRoot$OUT/mod-defaults -framework AppKit -framework Foundation &&
      tests/x11-guest-helper.sh tests/x11-modifier-defaults-helper.c /Volumes/SystemRoot$OUT/mod-defaults'

Source of behaviour: the documented `NSModifierFlagMapping` default as implemented by
`-[NSDisplay modifierForDefault:standard:]` (rung 2, in tree); no Apple binary inspected.
