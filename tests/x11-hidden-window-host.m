// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Runs the mapping methods of AppKit/X11.backend/X11Window.m against a real X server, inside a mock X11Window.
 *
 * tests/x11-hidden-window-host.sh cuts -ensureMapped (and any -ensureMapped... helper), -placeAboveWindow:,
 * -placeBelowWindow:, -makeKey and -hideWindow out of X11Window.m and runs this on its own Xvfb (no window
 * manager). -[NSWindow makeKeyWindow] reaches -makeKey whether or not the window is ordered in; making a window key
 * does not order it in (that is -makeKeyAndOrderFront:), so a hidden window must stay unmapped. */
#include <objc/runtime.h>
#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>

typedef long NSInteger;
typedef unsigned long NSUInteger;
typedef struct {
    double x, y, width, height;
} O2Rect;

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

// The window AppKit sees; -orderWindow:relativeTo: sets _isVisible before it calls the platform window.
@interface NSWindow : Object {
@public
    BOOL _isVisible;
}
- (BOOL)isVisible;
@end
@implementation NSWindow
- (BOOL)isVisible { return _isVisible; }
@end

static Display *display;
static int focusRequests;

@interface X11Window : Object {
@public
    Display *_display;
    Window _window;
    NSWindow *_delegate;
    O2Rect _frame;
    NSUInteger _styleMask;
    BOOL _mapped;
    BOOL _fullscreenRequested;
    BOOL _wantsInputFocus;
    BOOL _receivingFocus;
}
@end

static X11Window *windows[2];

@implementation X11Window
+ (X11Window *)windowWithWindowNumber:(NSInteger)number
{
    return number > 0 && number <= 2 ? windows[number - 1] : nil;
}
- (BOOL)wantsFullscreenWithStyleMask:(NSUInteger)mask frame:(O2Rect)frame
{
    (void)mask;
    (void)frame;
    return NO;
}
- (void)requestFullscreen:(BOOL)fullscreen force:(BOOL)force
{
    (void)fullscreen;
    (void)force;
}
- (void)requestInputFocus { focusRequests++; }
#include METHODS_INC
@end

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static X11Window *makeWindow(NSWindow *delegate)
{
    X11Window *window = [[X11Window alloc] init];
    window->_display = display;
    window->_delegate = delegate;
    window->_window = XCreateSimpleWindow(display, DefaultRootWindow(display), 10, 10, 100, 80, 0, 0, 0);
    return window;
}

// What the X server says, not the _mapped flag.
static BOOL serverMapped(X11Window *window)
{
    XWindowAttributes attributes;
    XSync(display, False);
    return XGetWindowAttributes(display, window->_window, &attributes) && attributes.map_state != IsUnmapped;
}

int main(void)
{
    display = XOpenDisplay(NULL);
    if (display == NULL) {
        printf("FAIL: cannot open the X display\n");
        return 1;
    }

    NSWindow *ns = [[NSWindow alloc] init];
    NSWindow *otherNS = [[NSWindow alloc] init];
    otherNS->_isVisible = YES;
    X11Window *window = makeWindow(ns);
    X11Window *other = makeWindow(otherNS);
    windows[0] = window;
    windows[1] = other;
    [other placeAboveWindow:0];
    CK(serverMapped(other), "ordering a visible window in maps it");

    [window makeKey];
    CK(!serverMapped(window), "-makeKey leaves a window AppKit has not shown unmapped");
    [window placeAboveWindow:2];
    CK(!serverMapped(window), "-placeAboveWindow: leaves a hidden window unmapped");
    [window placeBelowWindow:2];
    CK(!serverMapped(window), "-placeBelowWindow: leaves a hidden window unmapped");
    [window placeAboveWindow:0];
    CK(!serverMapped(window), "raising a hidden window leaves it unmapped");

    ns->_isVisible = YES; // -orderWindow:relativeTo: NSWindowAbove
    [window placeAboveWindow:2];
    CK(serverMapped(window), "ordering the window in maps it");

    ns->_isVisible = NO; // -orderWindow:relativeTo: NSWindowOut
    [window hideWindow];
    CK(!serverMapped(window), "ordering it out unmaps it");
    int before = focusRequests;
    [window makeKey];
    CK(!serverMapped(window), "-makeKey after -orderOut: does not map it again");
    CK(focusRequests == before + 1, "-makeKey still asks for the input focus");

    ns->_isVisible = YES; // -orderWindow:relativeTo: NSWindowBelow
    [window placeBelowWindow:2];
    CK(serverMapped(window), "ordering the window in below another maps it");
    [other hideWindow];
    otherNS->_isVisible = NO;

    X11Window *bare = makeWindow(nil);
    [bare makeKey];
    CK(serverMapped(bare), "a platform window without an NSWindow is still mapped by -makeKey");

    XCloseDisplay(display);
    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
