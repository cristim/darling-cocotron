Regression test for making a detached `NSOpenGLContext` current
(`feature/appkit-detached-opengl-context`). UNRUN: written without a build or a display.

`appkit-detached-gl-current.m` creates a double-buffered context, attaches it to a view
that is in no window, and checks that `-makeCurrentContext` makes it the thread's current
context both for AppKit (`+[NSOpenGLContext currentContext]`) and for CGL
(`CGLGetCurrentContext()`), then repeats it with no view. It uses no host helper.

## Before and after the fix

Before 2a023239c the detached path went through `CGLContextMakeCurrentAndAttachToWindow`
with a NULL window, which fails: the guest logs "CGLSetCurrentContext failed", leaves no
current context, and exits 1 with "makeCurrentContext on a detached view did not make the
context current". After it, the guest prints `PASS: appkit-detached-gl-current`.
Exit 77 means no GL context could be created on that display (no EGL/Mesa software
renderer): the check did not run and must not be counted as a pass.

## Command (builder)

Needs an X server with EGL (Mesa llvmpipe is enough), which Xvfb provides; the
`feature` branch's AppKit must be the one in the prefix.

    export DPREFIX=$HOME/.local/share/agent-tmp/gl-prefix
    export OUT=$HOME/.local/share/agent-tmp/gl-out; mkdir -p $OUT
    flock -w 1800 /tmp/agent-locks/darling-heavy-build.lock bash -c '
      darling shell clang /Volumes/SystemRoot$PWD/tests/appkit-detached-gl-current.m \
          -o /Volumes/SystemRoot$OUT/gl-current -framework AppKit -framework Foundation \
          -framework OpenGL &&
      xvfb-run -a -s "-screen 0 800x600x24" bash -c \
          "darling shell env DARLING_APPKIT_BACKEND=x11 DISPLAY=\$DISPLAY /Volumes/SystemRoot$OUT/gl-current"'

Manual fallback if the headless run exits 77: in a real X11 session create an
`NSOpenGLView` subclass whose `-initWithFrame:` calls `[[self openGLContext]
makeCurrentContext]` and then `glGetString(GL_VERSION)` before the view is added to a
window; the string must be non-NULL.

Source: in-tree NSOpenGLContext and CGL code (rung 2); public NSOpenGLContext documentation
(rung 3). No Apple binary inspected. Not covered: `prepareOpenGL` running on the first
attached `makeCurrentContext`, rendering into the context.
