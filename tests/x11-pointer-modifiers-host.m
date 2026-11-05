// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* A modifier release the window never sees, and the pointer events that follow it.
 *
 * tests/x11-pointer-modifiers-host.sh runs this on its own Xvfb with no window manager. One connection plays the
 * application: its window has the input focus when Super goes down. A second connection plays the compositor: it
 * grabs the keyboard, Super is released while the grab holds, and the grab ends, as GNOME's overview does. The
 * application gets the KeyPress but no KeyRelease, and the grab's FocusOut/FocusIn are NotifyGrab/NotifyUngrab,
 * which X11Display ignores. Its key path had set the aggregate to Command on the KeyPress.
 *
 * The pointer events the application gets next carry the server's real state. They are fed to X11Display's
 * -syncModifierFlags... method in a mock X11Display: the key window must get one NSFlagsChanged with the
 * no-single-key keycode (0xFFFF) and no Command flag before the first of them, and nothing after. */
#include <objc/runtime.h>
#include <X11/Xlib.h>
#include <X11/extensions/XTest.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

typedef unsigned long NSUInteger;
typedef NSUInteger NSEventModifierFlags;
enum {
    NSAlphaShiftKeyMask = 1 << 16,
    NSShiftKeyMask = 1 << 17,
    NSControlKeyMask = 1 << 18,
    NSAlternateKeyMask = 1 << 19,
    NSCommandKeyMask = 1 << 20,
    NSFunctionKeyMask = 1 << 23,
};

__attribute__((objc_root_class))
@interface Object {
    Class isa;
}
+ (id)alloc;
- (id)init;
@end
@implementation Object
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { return self; }
@end

@interface NSWindow : Object {
@public
    BOOL _isKeyWindow;
}
- (BOOL)isKeyWindow;
@end
@implementation NSWindow
- (BOOL)isKeyWindow { return _isKeyWindow; }
@end

@interface X11Window : Object {
@public
    NSWindow *_delegate;
}
- (NSWindow *)delegate;
@end
@implementation X11Window
- (NSWindow *)delegate { return _delegate; }
@end

static int posted;
static unsigned short postedKeyCode;
static NSEventModifierFlags postedFlags;

@interface X11Display : Object {
@public
    NSEventModifierFlags _modifierFlags;
}
- (void)syncModifierFlagsWithPointerEvent:(XEvent *)ev inWindow:(X11Window *)window;
@end
@implementation X11Display
- (void)postFlagsChanged:(unsigned short)keyCode flags:(NSEventModifierFlags)flags inWindow:(X11Window *)window
{
    (void)window;
    posted++;
    postedKeyCode = keyCode;
    postedFlags = flags;
}
#include METHODS_INC
@end

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

enum { SuperL = 133, maxEvents = 64 };
static XEvent events[maxEvents];
static int eventCount;

// Everything the application connection has received once the server has handled all requests so far.
static void collect(Display *app, Display *compositor)
{
    XSync(compositor, False);
    XSync(app, False);
    usleep(100 * 1000);
    while (XPending(app) && eventCount < maxEvents)
        XNextEvent(app, &events[eventCount++]);
}

static int countKey(int type, unsigned int keycode)
{
    int n = 0;
    for (int i = 0; i < eventCount; i++)
        n += events[i].type == type && events[i].xkey.keycode == keycode;
    return n;
}

int main(void)
{
    Display *app = XOpenDisplay(NULL), *compositor = XOpenDisplay(NULL);
    if (app == NULL || compositor == NULL) {
        printf("FAIL: cannot open the X display\n");
        return 1;
    }
    Window root = DefaultRootWindow(app);
    Window w = XCreateSimpleWindow(app, root, 0, 0, 200, 200, 0, 0, 0);
    XSelectInput(app, w, KeyPressMask | KeyReleaseMask | ButtonPressMask | ButtonReleaseMask | PointerMotionMask |
                                 EnterWindowMask | LeaveWindowMask | FocusChangeMask | ExposureMask);
    XMapWindow(app, w);
    XEvent ev;
    do
        XNextEvent(app, &ev);
    while (ev.type != Expose);
    XTestFakeMotionEvent(compositor, 0, 400, 400, CurrentTime);
    XSetInputFocus(app, w, RevertToPointerRoot, CurrentTime);
    collect(app, compositor);
    eventCount = 0;

    XTestFakeKeyEvent(compositor, SuperL, True, CurrentTime);
    collect(app, compositor);
    CK(countKey(KeyPress, SuperL) == 1, "the window gets the Super press");
    XGrabKeyboard(compositor, DefaultRootWindow(compositor), False, GrabModeAsync, GrabModeAsync, CurrentTime);
    XTestFakeKeyEvent(compositor, SuperL, False, CurrentTime);
    XUngrabKeyboard(compositor, CurrentTime);
    collect(app, compositor);
    CK(countKey(KeyRelease, SuperL) == 0, "the grab keeps the Super release from the window");

    int firstPointer = eventCount;
    XTestFakeMotionEvent(compositor, 0, 50, 50, CurrentTime);
    XTestFakeButtonEvent(compositor, 1, True, CurrentTime);
    XTestFakeButtonEvent(compositor, 1, False, CurrentTime);
    collect(app, compositor);
    int pointerEvents = 0;
    for (int i = firstPointer; i < eventCount; i++) {
        if (events[i].type == ButtonPress)
            CK(!(events[i].xbutton.state & Mod4Mask), "the click carries no Super (state 0x%x)", events[i].xbutton.state);
        pointerEvents += events[i].type == ButtonPress || events[i].type == ButtonRelease ||
                         events[i].type == MotionNotify || events[i].type == EnterNotify;
    }
    CK(pointerEvents >= 3, "the window gets the crossing, motion and click (%d events)", pointerEvents);

    if (!class_getInstanceMethod(objc_getClass("X11Display"), @selector(syncModifierFlagsWithPointerEvent:inWindow:))) {
        CK(0, "X11Display corrects the modifier flags from pointer events (-syncModifierFlagsWithPointerEvent:inWindow:)");
    } else {
        X11Display *display = [[X11Display alloc] init];
        X11Window *window = [[X11Window alloc] init];
        window->_delegate = [[NSWindow alloc] init];
        window->_delegate->_isKeyWindow = YES;
        display->_modifierFlags = NSCommandKeyMask; // what the Super KeyPress left behind

        // The key path, not this method, owns key events.
        for (int i = 0; i < firstPointer; i++)
            [display syncModifierFlagsWithPointerEvent:&events[i] inWindow:window];
        CK(posted == 0, "key and focus events are left to the key path (%d posted)", posted);

        int postedAt = -1;
        for (int i = firstPointer; i < eventCount; i++) {
            [display syncModifierFlagsWithPointerEvent:&events[i] inWindow:window];
            if (posted == 1 && postedAt < 0)
                postedAt = i;
        }
        CK(posted == 1, "one NSFlagsChanged for the pointer events (%d)", posted);
        CK(postedAt == firstPointer, "posted ahead of the first pointer event");
        CK(postedKeyCode == 0xFFFF, "with the no-single-key keycode (0x%x)", postedKeyCode);
        CK(postedFlags == 0 && display->_modifierFlags == 0, "Command is released (0x%lx)", postedFlags);

        XEvent sent = events[eventCount - 1];
        sent.xany.send_event = True;
        sent.xbutton.state = Mod4Mask;
        [display syncModifierFlagsWithPointerEvent:&sent inWindow:window];
        CK(posted == 1 && display->_modifierFlags == 0, "an event another client sent is not trusted");

        XEvent shifted = events[eventCount - 1];
        shifted.xbutton.state = ShiftMask;
        window->_delegate->_isKeyWindow = NO;
        [display syncModifierFlagsWithPointerEvent:&shifted inWindow:window];
        CK(posted == 1 && display->_modifierFlags == 0, "a window that is not key gets no NSFlagsChanged");
        window->_delegate->_isKeyWindow = YES;
        [display syncModifierFlagsWithPointerEvent:&shifted inWindow:window];
        CK(posted == 2 && postedFlags == NSShiftKeyMask && display->_modifierFlags == NSShiftKeyMask,
           "a modifier held on a click in the key window is reported");
    }

    XCloseDisplay(compositor);
    XCloseDisplay(app);
    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
