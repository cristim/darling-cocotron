// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Runs the X11 decoration code of AppKit/X11.backend/X11Window.m and the title bar accessors of AppKit/NSWindow.m
 * against a real X server, inside mock X11Window and NSWindow classes.
 *
 * tests/x11-decorations-host.sh cuts the methods out of the sources and runs this on its own Xvfb. The window
 * manager reads _MOTIF_WM_HINTS: flags bit 1 with decorations 0 asks for no title bar or border; without the
 * property the window manager decorates the window. Apple documents NSWindowStyleMaskTitled as "the window displays
 * a title bar", so an untitled window must carry the hint and a titled one must not, also after -setStyleMask:.
 * A titled window whose title bar is transparent with a hidden title draws its own chrome. */
#include <objc/runtime.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef long NSInteger;
typedef unsigned long NSUInteger;
typedef struct {
    double x, y, width, height;
} O2Rect;
typedef NSUInteger NSWindowStyleMask;
typedef NSInteger NSWindowTitleVisibility;
enum { NSWindowTitleVisible = 0, NSWindowTitleHidden = 1 };
enum {
    NSWindowStyleMaskBorderless = 0,
    NSBorderlessWindowMask = 0,
    NSWindowStyleMaskTitled = 0x01,
    NSWindowStyleMaskClosable = 0x02,
    NSWindowStyleMaskResizable = 0x08,
    NSWindowStyleMaskFullSizeContentView = 0x8000,
};
#define NSLog(...) ((void) 0)

__attribute__((objc_root_class))
@interface Object {
    Class isa;
}
+ (id)alloc;
+ (Class)class;
- (Class)class;
- (id)init;
- (BOOL)isKindOfClass:(Class)aClass;
@end
@implementation Object
+ (id)alloc { return class_createInstance(self, 0); }
+ (Class)class { return self; }
- (Class)class { return object_getClass(self); }
- (id)init { return self; }
- (BOOL)isKindOfClass:(Class)aClass
{
    for (Class c = object_getClass(self); c != Nil; c = class_getSuperclass(c))
        if (c == aClass)
            return YES;
    return NO;
}
@end

@class X11Window;

@interface NSWindow : Object {
@public
    X11Window *_platformWindow;
    NSWindowStyleMask _styleMask;
    BOOL _titlebarAppearsTransparent;
    NSWindowTitleVisibility _titleVisibility;
}
- (BOOL)titlebarAppearsTransparent;
- (void)setTitlebarAppearsTransparent:(BOOL)transparent;
- (NSWindowTitleVisibility)titleVisibility;
- (void)setTitleVisibility:(NSWindowTitleVisibility)value;
@end
@interface NSPanel : NSWindow
@end

@interface X11Window : Object {
@public
    Display *_display;
    Window _window;
    NSWindow *_delegate;
    O2Rect _frame;
    NSUInteger _styleMask;
}
- (void)setStyleMask:(NSUInteger)mask;
@end

@implementation NSWindow
#include NSWINDOW_INC
@end
@implementation NSPanel
@end

@implementation X11Window
- (void)updateSizeHints:(NSUInteger)mask { (void)mask; }
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
#include X11WINDOW_INC
// The end of -initWithDelegate:, after the X window exists.
- (void)finishInit
{
    BOOL isPanel = [_delegate isKindOfClass:[NSPanel class]];
    (void)isPanel;
#include INIT_INC
}
@end

static Display *display;
static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

// -[NSWindow initWithContentRect:...] creates the platform window with the delegate's properties already set.
static X11Window *create(Class cls, NSWindowStyleMask mask, BOOL transparent, NSWindowTitleVisibility visibility)
{
    NSWindow *ns = [[cls alloc] init];
    ns->_styleMask = mask;
    ns->_titlebarAppearsTransparent = transparent;
    ns->_titleVisibility = visibility;
    X11Window *window = [[X11Window alloc] init];
    window->_display = display;
    window->_delegate = ns;
    window->_styleMask = mask;
    window->_window = XCreateSimpleWindow(display, DefaultRootWindow(display), 10, 10, 100, 80, 0, 0, 0);
    [window finishInit];
    ns->_platformWindow = window;
    return window;
}

// -[NSWindow setStyleMask:]
static void setStyle(X11Window *window, NSWindowStyleMask mask)
{
    window->_delegate->_styleMask = mask;
    [window setStyleMask:mask];
}

// YES when the window asks the window manager for no decorations, NO when the property is absent (decorated).
// Anything else fails the check that reads it.
static int undecorated(X11Window *window)
{
    Atom motif = XInternAtom(display, "_MOTIF_WM_HINTS", False), type;
    int format;
    unsigned long count, remaining;
    unsigned char *data = NULL;
    XSync(display, False);
    if (XGetWindowProperty(display, window->_window, motif, 0, 5, False, AnyPropertyType, &type, &format, &count,
                           &remaining, &data) != Success)
        return -1;
    int result = -1;
    if (type == None)
        result = NO;
    else if (type == motif && format == 32 && count == 5) {
        long *hints = (long *) data;
        if ((hints[0] & 2) && hints[2] == 0)
            result = YES;
    }
    if (data)
        XFree(data);
    return result;
}

int main(void)
{
    display = XOpenDisplay(NULL);
    if (display == NULL) {
        printf("FAIL: cannot open the X display\n");
        return 1;
    }
    Class window = [NSWindow class], panel = [NSPanel class];
    NSWindowStyleMask titled = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;

    X11Window *w = create(window, titled, NO, NSWindowTitleVisible);
    CK(undecorated(w) == NO, "a titled window is decorated");
    [w->_delegate setTitleVisibility:NSWindowTitleHidden];
    CK(undecorated(w) == NO, "hiding only the title keeps the title bar");
    [w->_delegate setTitlebarAppearsTransparent:YES];
    CK(undecorated(w) == YES, "a transparent title bar with a hidden title is client-drawn: no decorations");
    [w->_delegate setTitlebarAppearsTransparent:NO];
    CK(undecorated(w) == NO, "an opaque title bar again: decorated");
    [w->_delegate setTitlebarAppearsTransparent:YES];
    [w->_delegate setTitleVisibility:NSWindowTitleVisible];
    CK(undecorated(w) == NO, "showing the title again: decorated");

    w = create(window, titled | NSWindowStyleMaskFullSizeContentView, YES, NSWindowTitleHidden);
    CK(undecorated(w) == YES, "title bar properties set before the X window exists: no decorations");

    w = create(window, titled, NO, NSWindowTitleVisible);
    setStyle(w, NSWindowStyleMaskBorderless);
    CK(undecorated(w) == YES, "-setStyleMask: borderless removes the decorations");
    setStyle(w, titled);
    CK(undecorated(w) == NO, "-setStyleMask: titled again gives them back");

    w = create(window, NSWindowStyleMaskBorderless, NO, NSWindowTitleVisible);
    CK(undecorated(w) == YES, "a borderless window is not decorated");
    setStyle(w, NSWindowStyleMaskTitled);
    CK(undecorated(w) == NO, "a borderless window made titled is decorated");

    w = create(window, NSWindowStyleMaskResizable | NSWindowStyleMaskClosable, NO, NSWindowTitleVisible);
    CK(undecorated(w) == YES, "an untitled window with other style bits is not decorated");
    setStyle(w, NSWindowStyleMaskResizable);
    CK(undecorated(w) == YES, "still untitled after -setStyleMask:");

    w = create(panel, titled, NO, NSWindowTitleVisible);
    CK(undecorated(w) == YES, "a panel is not decorated (unchanged)");
    setStyle(w, NSWindowStyleMaskTitled);
    CK(undecorated(w) == YES, "a panel stays undecorated after -setStyleMask:");

    XCloseDisplay(display);
    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
