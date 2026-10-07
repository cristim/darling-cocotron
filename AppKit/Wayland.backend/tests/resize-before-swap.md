Build resize-before-swap.m against AppKit, QuartzCore, Foundation and OpenGL.
Run with DARLING_APPKIT_BACKEND=wayland on a private native compositor. With
RESIZE_CONTROL unset the fixture runs six swaps and exits. To capture each
stage, set RESIZE_CONTROL to a guest-visible text file and write successive
integers 0 through 5 after each PRESENTED line and screenshot.

The fixture renders before changing native child geometry, preserving an old
backbuffer during a grow and shrink. Subsequent swaps leave geometry unchanged
and attach the newly sized buffer. On the original backend it disconnects after
stage1 because a320x180 source is committed with a120x80 buffer. A passing
backend completes all six stages with RESULT failures=0 and no protocol error.

Capture native pixels: stage0 red120x80; stages1/2 green320x180;
stages3/4 blue90x60; stage5 red90x60 (at output scale1). Verify the colored
rectangle dimensions as well as the wire crop against the actual attachment.
Process liveness and successful CGLFlushDrawable alone are insufficient.
