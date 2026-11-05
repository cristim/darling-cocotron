// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Runs the real -[NSThemeFrame resizeSubviewsWithOldSize:] in a mock view hierarchy.
 *
 * tests/themeframe-content-resize-host.sh cuts the method (and +titleBarHeightForStyleMask:) out of
 * NSThemeFrame.m. The theme frame is the window's top view; when the window resizes it gives the window's content
 * view (Apple: contentView, "the window's content view, the highest accessible view object in the window's view
 * hierarchy") the content rectangle. Other subviews an app adds to it (above the content view, for example an
 * overlay) are not the content view; like any NSView subview they follow their autoresizing masks
 * (resizeSubviewsWithOldSize: "informs the view's subviews that the view's bounds rectangle size has changed"). */
#include <objc/runtime.h>
#include <stdio.h>

typedef double CGFloat;
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef struct { CGFloat x, y; } NSPoint;
typedef struct { CGFloat width, height; } NSSize;
typedef struct { NSPoint origin; NSSize size; } NSRect;
static const NSRect NSZeroRect;
static NSRect R(CGFloat x, CGFloat y, CGFloat w, CGFloat h) { NSRect r = { { x, y }, { w, h } }; return r; }
static CGFloat NSMaxY(NSRect r) { return r.origin.y + r.size.height; }
static int same(NSRect a, NSRect b)
{
    return a.origin.x == b.origin.x && a.origin.y == b.origin.y && a.size.width == b.size.width &&
           a.size.height == b.size.height;
}
enum { NSWindowStyleMaskTitled = 1 };
static const CGFloat kTitleBarHeight = 28.0;
typedef struct { unsigned long state; id *itemsPtr; unsigned long *mutationsPtr; unsigned long extra[5]; }
    NSFastEnumerationState;

__attribute__((objc_root_class))
@interface Object { Class isa; }
+ (id)alloc; + (Class)class; - (Class)class; - (id)init; - (id)autorelease; - (BOOL)isKindOfClass:(Class)c;
@end
@implementation Object
+ (id)alloc { return class_createInstance(self, 0); }
+ (Class)class { return self; }
- (Class)class { return object_getClass(self); }
- (id)init { return self; }
- (id)autorelease { return self; }
- (BOOL)isKindOfClass:(Class)c
{
    for (Class k = object_getClass(self); k; k = class_getSuperclass(k)) if (k == c) return YES;
    return NO;
}
@end

@interface List : Object { @public id _items[16]; NSUInteger _n; }
- (id)copy;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)b count:(NSUInteger)n;
@end
@implementation List
- (id)copy { List *c = [[List alloc] init]; for (NSUInteger i = 0; i < _n; i++) c->_items[i] = _items[i]; c->_n = _n; return c; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)b count:(NSUInteger)n
{
    if (st->state) return 0;
    st->state = 1; st->itemsPtr = _items; st->mutationsPtr = &st->extra[0];
    return _n;
}
@end

@class NSWindow;
@interface NSView : Object {
@public
    List *_subviews;
    NSView *_super;
    NSRect _frame;
    NSWindow *_window;
    int autoresized;
    NSSize lastOldSize;
}
- (void)addSubview:(NSView *)v; - (NSView *)superview; - (NSWindow *)window;
- (NSRect)frame; - (NSRect)bounds; - (void)setFrame:(NSRect)f; - (void)resizeWithOldSuperviewSize:(NSSize)s;
@end
@implementation NSView
- (id)init { _subviews = [[List alloc] init]; return self; }
- (void)addSubview:(NSView *)v { _subviews->_items[_subviews->_n++] = v; v->_super = self; }
- (NSView *)superview { return _super; }
- (NSWindow *)window { return _window; }
- (NSRect)frame { return _frame; }
- (NSRect)bounds { return R(0, 0, _frame.size.width, _frame.size.height); }
- (void)setFrame:(NSRect)f { _frame = f; }
- (void)resizeWithOldSuperviewSize:(NSSize)s { autoresized++; lastOldSize = s; }
@end
@interface NSThemeFrameButton : NSView @end
@implementation NSThemeFrameButton @end
@interface NSMenuView : NSView @end
@implementation NSMenuView @end
@interface NSToolbarView : NSView - (void)layoutViews; @end
@implementation NSToolbarView - (void)layoutViews {} @end
@interface NSMainMenuView : NSView + (CGFloat)menuHeight; @end
@implementation NSMainMenuView + (CGFloat)menuHeight { return 20; } @end

@interface NSWindow : Object { @public NSView *_content; NSUInteger _style; }
+ (NSRect)contentRectForFrameRect:(NSRect)r styleMask:(NSUInteger)m; + (BOOL)hasMainMenuForStyleMask:(NSUInteger)m;
- (NSView *)contentView; - (NSUInteger)styleMask; - (BOOL)hasMainMenu;
@end
@implementation NSWindow
+ (NSRect)contentRectForFrameRect:(NSRect)r styleMask:(NSUInteger)m { return r; }
+ (BOOL)hasMainMenuForStyleMask:(NSUInteger)m { return NO; }
- (NSView *)contentView { return _content; }
- (NSUInteger)styleMask { return _style; }
- (BOOL)hasMainMenu { return NO; }
@end

@interface NSThemeFrame : NSView
+ (CGFloat)titleBarHeightForStyleMask:(NSUInteger)styleMask;
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize;
- (void)layoutTrafficLights;
@end
@implementation NSThemeFrame
- (void)layoutTrafficLights {}
#include METHODS_INC
@end

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static NSThemeFrame *frameFor(NSWindow *w, NSUInteger style)
{
    NSThemeFrame *f = [[NSThemeFrame alloc] init];
    f->_window = w; w->_style = style;
    f->_frame = R(0, 0, 400, 300);
    return f;
}

int main(void)
{
    NSSize old = { 200, 100 };
    NSWindow *w = [[NSWindow alloc] init];

    // Content view first, then an app-added overlay sibling.
    NSThemeFrame *f = frameFor(w, 0);
    NSView *content = [[NSView alloc] init], *overlay = [[NSView alloc] init];
    NSThemeFrameButton *button = [[NSThemeFrameButton alloc] init];
    w->_content = content;
    [f addSubview:content]; [f addSubview:overlay]; [f addSubview:button];
    content->_frame = overlay->_frame = R(0, 0, 200, 100);
    [f resizeSubviewsWithOldSize:old];
    CK(same(content->_frame, R(0, 0, 400, 300)), "the window's content view gets the content rect (got %gx%g)",
       content->_frame.size.width, content->_frame.size.height);
    CK(same(overlay->_frame, R(0, 0, 200, 100)), "an overlay added after it is not given the content rect (got %gx%g)",
       overlay->_frame.size.width, overlay->_frame.size.height);
    CK(overlay->autoresized == 1 && overlay->lastOldSize.width == 200 && overlay->lastOldSize.height == 100,
       "the overlay is autoresized once with the old size (%d calls)", overlay->autoresized);
    CK(content->autoresized == 0 && button->autoresized == 0, "neither the content view nor a traffic light is autoresized");

    // The content view inside a full-size wrapper: the wrapper is what the theme frame tiles.
    NSThemeFrame *g = frameFor(w, 0);
    NSView *wrapper = [[NSView alloc] init], *inner = [[NSView alloc] init], *badge = [[NSView alloc] init];
    [g addSubview:wrapper]; [wrapper addSubview:inner]; [g addSubview:badge];
    w->_content = inner;
    [g resizeSubviewsWithOldSize:old];
    CK(same(wrapper->_frame, R(0, 0, 400, 300)), "the wrapper holding the content view gets the content rect");
    CK(same(badge->_frame, NSZeroRect) && badge->autoresized == 1, "a later sibling of the wrapper is only autoresized");

    // A titled window: the title bar comes out of the content rect.
    NSThemeFrame *h = frameFor(w, NSWindowStyleMaskTitled);
    NSView *only = [[NSView alloc] init];
    [h addSubview:only];
    w->_content = only;
    [h resizeSubviewsWithOldSize:old];
    CK(same(only->_frame, R(0, kTitleBarHeight, 400, 300 - kTitleBarHeight)), "a titled content view loses the title bar (got y %g h %g)",
       only->_frame.origin.y, only->_frame.size.height);

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
