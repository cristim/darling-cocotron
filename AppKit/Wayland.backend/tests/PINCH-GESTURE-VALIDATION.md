# Wayland pinch-gesture validation

## Scope

When the compositor advertises `zwp_pointer_gestures_v1`, the backend requests
a pinch object for its pointer and turns touchpad pinches into AppKit magnify
and rotate events (`NSEventTypeMagnify`, `NSEventTypeRotate`) with
`phase`, `magnification` and `rotation` set. Wayland reports the scale relative
to the start of the pinch and clockwise degrees since the previous update;
AppKit events carry the change in magnification and counterclockwise degrees.
Swipe and hold gestures are not translated.

## Private runtime fixture

Build `pinch-gesture-dispatch.m` like `scroll-frame-dispatch.m` and run it
against an isolated headless compositor and a disposable Darling prefix:

```sh
env XDG_RUNTIME_DIR=<private dir> WLR_BACKENDS=headless WLR_RENDERER=pixman \
    WLR_LIBINPUT_NO_DEVICES=1 sway -c <config> &
darling shell env DARLING_APPKIT_BACKEND=wayland \
    WAYLAND_DISPLAY=<private dir>/wayland-1 /path/to/pinch-gesture-dispatch
```

It takes the pointer capability (so `get_pinch_gesture` goes over the wire),
drives the real pinch entry point and checks began/changed/ended/cancelled
phases, the magnification and rotation conversions, updates that change
nothing, window unmap and pointer-capability loss during a pinch, and that
NSWindow delivers the events to the view under the pointer. Expected result:
`RESULT checks=11 failures=0`.
