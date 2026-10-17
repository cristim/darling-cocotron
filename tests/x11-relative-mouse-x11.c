// Host test for AppKit/X11.backend/X11RelativeMouseGrab.h, the Xlib half of relative mouse mode, on a real X server.
// XTest supplies the physical motion; the test pumps the connection's events through the same functions the backend
// calls, and checks that the cursor stays frozen, the deltas add up, and a warp's own echo is never taken for
// motion (no feedback loop). Use tests/x11-relative-mouse-x11.sh, which runs it on its own Xvfb.
// Build: cc x11-relative-mouse-x11.c -lX11 -lXtst -lXrandr -lm
#include "../AppKit/X11.backend/X11Monitors.h"
#include "../AppKit/X11.backend/X11RelativeMouseGrab.h"
#include <X11/extensions/XTest.h>
#include <X11/extensions/Xrandr.h>
#include <stdio.h>
#include <stdlib.h>

static int failures, checks;

#define CHECK(condition, ...)                                                                               \
    do {                                                                                                    \
        checks++;                                                                                           \
        if (!(condition)) {                                                                                 \
            failures++;                                                                                     \
            printf("FAIL %s:%d: ", __FILE__, __LINE__);                                                     \
            printf(__VA_ARGS__);                                                                            \
            printf("\n");                                                                                   \
        }                                                                                                   \
    } while (0)

typedef struct {
    double deltaX, deltaY;
    int posted, echoes, motions, events;
} Pumped;

/* Handles every queued event the way X11Display does while relative mode is active. */
static bool pump(Display *display, X11RelativeMouse *mouse, bool honoured, Pumped *total) {
    XSync(display, False);
    for (int guard = 0; XPending(display) > 0; guard++) {
        if (guard > 5000) {
            printf("FAIL: events keep coming after %d, a warp feedback loop\n", guard);
            failures++;
            return false;
        }
        XEvent event;
        XNextEvent(display, &event);
        total->events++;
        if (event.type != MotionNotify) {
            if (mouse->active)
                X11RelativeMouseTick(mouse);
            continue;
        }
        total->motions++;
        bool ok;
        X11RelativeMouseMotion motion = X11RelativeMouseMotionEvent(display, mouse, &event.xmotion, honoured, &ok);
        CHECK(ok, "echo recorded");
        if (motion.echo)
            total->echoes++;
        if (motion.post) {
            total->posted++;
            total->deltaX += motion.deltaX;
            total->deltaY += motion.deltaY;
        }
    }
    return true;
}

static void queryPointer(Display *display, int *x, int *y) {
    Window root, child;
    int wx, wy;
    unsigned int mask;
    XQueryPointer(display, DefaultRootWindow(display), &root, &child, x, y, &wx, &wy, &mask);
}

static void move(Display *display, int dx, int dy) {
    XTestFakeRelativeMotionEvent(display, dx, dy, CurrentTime);
    XFlush(display);
}

/* -warpMouse: takes the space +[NSEvent mouseLocation] reports (Cocoa, y up from the main monitor's bottom-left):
 * warping to the reported location of the real pointer, or of the frozen relative-mode cursor, lands on the
 * pointer. The conversions are X11Monitors.h's, which the backend calls. */
static void globalPointRoundTrip(void) {
    X11Frame layouts[] = {{0, 0, 1280, 720}, {1280, 0, 1920, 1080}, {0, 360, 1280, 720}};
    for (int l = 0; l < 3; l++)
        for (int rootX = 0; rootX < 1280; rootX += 97)
            for (int rootY = 0; rootY < 720; rootY += 61) {
                X11Point cocoa = X11PointFromRoot(layouts[l], (X11Point){rootX, rootY});
                X11Point back = X11PointToRoot(layouts[l], cocoa);
                CHECK(back.x == rootX && back.y == rootY, "layout %d: root %d,%d came back as %g,%g", l, rootX, rootY,
                      back.x, back.y);
            }
}

int main(void) {
    Display *display = XOpenDisplay(NULL);
    if (!display) {
        printf("no X display: run through tests/x11-relative-mouse-x11.sh\n");
        return 2;
    }
    int eventBase, errorBase, major, minor;
    if (!XTestQueryExtension(display, &eventBase, &errorBase, &major, &minor)) {
        printf("the X server has no XTest\n");
        return 2;
    }
    Window root = DefaultRootWindow(display);
    Window window = XCreateSimpleWindow(display, root, 100, 100, 400, 300, 0, 0, 0);
    XSelectInput(display, window, PointerMotionMask | FocusChangeMask);
    XMapWindow(display, window);
    XSync(display, False);

    X11RelativeMouse mouse = {0};
    int px, py;

    /* Not focused: nothing is grabbed (a grab would take the pointer from whoever has the focus). */
    XSetInputFocus(display, root, RevertToPointerRoot, CurrentTime);
    CHECK(X11RelativeMouseGrab(display, &mouse, window) == X11_RELATIVE_MOUSE_NOT_FOCUSED && !mouse.active,
          "an unfocused window does not grab");

    /* A window manager may focus the frame it put around the client. */
    Window frame = XCreateSimpleWindow(display, root, 50, 50, 500, 400, 0, 0, 0);
    Window client = XCreateSimpleWindow(display, frame, 10, 10, 300, 200, 0, 0, 0);
    XMapSubwindows(display, frame);
    XMapWindow(display, frame);
    XSync(display, False);
    XSetInputFocus(display, frame, RevertToNone, CurrentTime);
    CHECK(X11RelativeMouseWindowHasFocus(display, client), "focus on the frame counts for the client");
    CHECK(!X11RelativeMouseWindowHasFocus(display, window), "focus on an unrelated frame does not count");
    XDestroyWindow(display, frame);

    XSetInputFocus(display, window, RevertToNone, CurrentTime);
    XWarpPointer(display, None, root, 0, 0, 0, 0, 300, 250);
    XSync(display, False);
    CHECK(X11RelativeMouseGrab(display, &mouse, window) == GrabSuccess && mouse.active, "grab on the focused window");
    CHECK(mouse.virtualX == 300 && mouse.virtualY == 250, "virtual cursor starts at the pointer");
    CHECK(mouse.minX == 100 && mouse.minY == 100 && mouse.maxX == 499 && mouse.maxY == 399,
          "bounds are the grab window: %d,%d %d,%d", mouse.minX, mouse.minY, mouse.maxX, mouse.maxY);
    Pumped warmup = {0};
    pump(display, &mouse, true, &warmup);

    /* One physical move at a time: a delta each, the cursor stays frozen, the pointer is put back. */
    srand(7);
    double sentX = 0, sentY = 0;
    Pumped single = {0};
    int worstEvents = 0, movedBack = 0, steps = 0;
    for (int i = 0; i < 100; i++) {
        int dx = rand() % 41 - 20, dy = rand() % 41 - 20;
        if (!dx && !dy)
            continue;
        steps++;
        int before = single.events;
        move(display, dx, dy);
        sentX += dx;
        sentY += dy;
        if (!pump(display, &mouse, true, &single))
            return 1;
        if (single.events - before > worstEvents)
            worstEvents = single.events - before;
        queryPointer(display, &px, &py);
        if (px == 300 && py == 250)
            movedBack++;
    }
    CHECK(single.deltaX == sentX && single.deltaY == sentY, "deltas add up: got %g,%g, sent %g,%g", single.deltaX,
          single.deltaY, sentX, sentY);
    CHECK(single.posted == steps, "one posted motion per physical move: %d of %d", single.posted, steps);
    CHECK(movedBack == steps, "the pointer was put back under the cursor after %d of %d moves", movedBack, steps);
    CHECK(mouse.virtualX == 300 && mouse.virtualY == 250, "the virtual cursor never moved");
    CHECK(worstEvents <= 3, "at most a motion and its warp's echo per move (worst %d)", worstEvents);
    CHECK(single.echoes >= steps / 2, "warp echoes were recognised: %d", single.echoes);

    /* A burst queued before any is handled: the sum is still exact and the pointer ends under the cursor. */
    Pumped burst = {0};
    sentX = sentY = 0;
    for (int i = 0; i < 30; i++) {
        int dx = rand() % 7 - 3, dy = rand() % 7 - 3;
        move(display, dx, dy);
        sentX += dx;
        sentY += dy;
    }
    XSync(display, False);
    pump(display, &mouse, true, &burst);
    queryPointer(display, &px, &py);
    CHECK(burst.deltaX == sentX && burst.deltaY == sentY, "burst deltas add up: got %g,%g, sent %g,%g", burst.deltaX,
          burst.deltaY, sentX, sentY);
    CHECK(px == 300 && py == 250, "after a burst the pointer is under the cursor: %d,%d", px, py);

    /* The application warps the cursor: it moves without a delta, then motion continues from there. */
    Pumped warp = {0};
    CHECK(X11RelativeMouseApplicationWarp(display, &mouse, 200, 180, true), "application warp");
    pump(display, &mouse, true, &warp);
    queryPointer(display, &px, &py);
    CHECK(mouse.virtualX == 200 && mouse.virtualY == 180 && px == 200 && py == 180,
          "the warp moved the cursor and the pointer: virtual %g,%g pointer %d,%d", mouse.virtualX, mouse.virtualY, px,
          py);
    CHECK(warp.posted == 0 && warp.deltaX == 0 && warp.deltaY == 0, "a warp produces no delta (%d posted)", warp.posted);
    move(display, 5, 7);
    pump(display, &mouse, true, &warp);
    queryPointer(display, &px, &py);
    CHECK(warp.deltaX == 5 && warp.deltaY == 7 && px == 200 && py == 180, "motion continues from the warp target: %g,%g, pointer %d,%d",
          warp.deltaX, warp.deltaY, px, py);

    /* A warp outside the grab window is clamped, as the server clips it; the pointer is parked inside the edge. */
    X11RelativeMouseApplicationWarp(display, &mouse, 10, 10, true);
    pump(display, &mouse, true, &warp);
    queryPointer(display, &px, &py);
    CHECK(mouse.virtualX == 100 && mouse.virtualY == 100 && px == 164 && py == 164,
          "an out-of-window warp is clamped: virtual %g,%g pointer %d,%d", mouse.virtualX, mouse.virtualY, px, py);

    /* A cursor frozen 3 pixels from the left edge: ten moves of -20 are all delivered, not clipped to the 3 left. */
    X11RelativeMouseApplicationWarp(display, &mouse, 103, 250, true);
    pump(display, &mouse, true, &warp);
    Pumped edge = {0};
    for (int i = 0; i < 10; i++) {
        move(display, -20, 0);
        if (!pump(display, &mouse, true, &edge))
            return 1;
    }
    CHECK(edge.deltaX == -200 && edge.deltaY == 0, "deltas near the edge are not clipped: %g,%g", edge.deltaX,
          edge.deltaY);
    CHECK(mouse.virtualX == 103 && mouse.virtualY == 250, "the cursor stayed at the edge: %g,%g", mouse.virtualX,
          mouse.virtualY);

    /* The window shrinks under the grab and the cached bounds are stale: a warp the server cannot honour exactly
     * must not start a warp feedback loop, and its clamped echo is not motion. */
    XResizeWindow(display, window, 100, 100);
    XSync(display, False);
    Pumped shrink = {0};
    if (!pump(display, &mouse, true, &shrink))
        return 1;
    shrink = (Pumped){0};
    CHECK(X11RelativeMouseApplicationWarp(display, &mouse, 450, 350, true), "warp to a point the old bounds allowed");
    if (!pump(display, &mouse, true, &shrink))
        return 1;
    queryPointer(display, &px, &py);
    CHECK(shrink.posted == 0 && shrink.deltaX == 0 && shrink.deltaY == 0,
          "an unreachable warp is no motion: %d posted, %g,%g", shrink.posted, shrink.deltaX, shrink.deltaY);
    CHECK(shrink.motions <= 3, "no feedback loop: %d motion events", shrink.motions);
    CHECK((int) mouse.virtualX == px && (int) mouse.virtualY == py,
          "the cursor settles where the pointer is: virtual %g,%g pointer %d,%d", mouse.virtualX, mouse.virtualY, px, py);
    shrink = (Pumped){0};
    move(display, -3, -2);
    if (!pump(display, &mouse, true, &shrink))
        return 1;
    CHECK(shrink.deltaX == -3 && shrink.deltaY == -2, "motion continues after the clamped warp: %g,%g", shrink.deltaX,
          shrink.deltaY);
    XResizeWindow(display, window, 400, 300);
    XSync(display, False);

    X11RelativeMouseRelease(display, &mouse);
    CHECK(!mouse.active, "released");
    X11RelativeMouseRelease(display, &mouse);
    CHECK(!mouse.active, "releasing twice is harmless");

    /* Warps not honoured (Xwayland with a visible cursor): the cursor follows the pointer, nothing is warped back. */
    XWarpPointer(display, None, root, 0, 0, 0, 0, 300, 250);
    XSync(display, False);
    CHECK(X11RelativeMouseGrab(display, &mouse, window) == GrabSuccess, "second grab");
    Pumped idle = {0};
    pump(display, &mouse, false, &idle);
    Pumped follow = {0};
    move(display, 10, 0);
    pump(display, &mouse, false, &follow);
    queryPointer(display, &px, &py);
    CHECK(follow.deltaX == 10 && follow.deltaY == 0, "delta reported: %g,%g", follow.deltaX, follow.deltaY);
    CHECK(px == 310 && py == 250 && mouse.virtualX == 310 && mouse.virtualY == 250,
          "the cursor follows the pointer: virtual %g,%g pointer %d,%d", mouse.virtualX, mouse.virtualY, px, py);
    X11RelativeMouseRelease(display, &mouse);

    /* The root shrinks: the bounds follow it although Xlib's cached DisplayWidth/Height are still the old size. */
    X11RelativeMouseBounds bounds;
    int screen = DefaultScreen(display);
    XRRScreenResources *resources = XRRGetScreenResources(display, root);
    XRRSetCrtcConfig(display, resources, resources->crtcs[0], CurrentTime, 0, 0, None, RR_Rotate_0, NULL, 0);
    XRRFreeScreenResources(resources);
    XRRSetScreenSize(display, root, 400, 300, DisplayWidthMM(display, screen) / 3, DisplayHeightMM(display, screen) / 2);
    XSync(display, False);
    CHECK(X11RelativeMouseWindowBounds(display, window, &bounds) && bounds.maxX == 399 && bounds.maxY == 299,
          "bounds are clipped to the shrunken root: %d,%d", bounds.maxX, bounds.maxY);

    globalPointRoundTrip();
    X11RelativeMouseEnd(&mouse);
    XCloseDisplay(display);
    if (failures) {
        printf("%d of %d checks FAILED\n", failures, checks);
        return 1;
    }
    printf("PASS: %d checks\n", checks);
    return 0;
}
