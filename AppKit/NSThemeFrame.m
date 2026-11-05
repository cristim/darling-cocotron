/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSMainMenuView.h>
#import <AppKit/NSMenuView.h>
#import <AppKit/NSThemeFrame.h>
#import <AppKit/NSToolbarView.h>
#import <AppKit/NSWindow-Private.h>
#import <AppKit/NSWindow.h>

@interface NSWindow (private)
- (BOOL) hasMainMenu;
+ (BOOL) hasMainMenuForStyleMask: (NSUInteger) styleMask;
@end

static const CGFloat kTitleBarHeight = 28.0;


@implementation NSThemeFrameButton

- (BOOL) isOpaque { return NO; }

- (void) drawRect: (NSRect) rect {
    NSColor *fill;

    if (![[self window] isKeyWindow]) {
        fill = [NSColor colorWithCalibratedWhite: 0.86 alpha: 1.0];
    } else if ([self tag] == 0) {
        fill = [NSColor colorWithCalibratedRed: 1.00 green: 0.37 blue: 0.34 alpha: 1.0];
    } else if ([self tag] == 1) {
        fill = [NSColor colorWithCalibratedRed: 0.99 green: 0.74 blue: 0.18 alpha: 1.0];
    } else {
        fill = [NSColor colorWithCalibratedRed: 0.16 green: 0.78 blue: 0.25 alpha: 1.0];
    }

    [fill setFill];
    [[NSBezierPath bezierPathWithOvalInRect: [self bounds]] fill];
}

@end

@implementation NSThemeFrame

+ (CGFloat) titleBarHeightForStyleMask: (NSUInteger) styleMask {
    if (styleMask & NSWindowStyleMaskTitled)
        return kTitleBarHeight;
    return 0.0;
}

- (BOOL) isOpaque {
    return YES;
}

- (void) addSubview: (NSView *) view {
    [super addSubview: view];
    if (![view isKindOfClass: [NSThemeFrameButton class]] &&
        ![view isKindOfClass: [NSMenuView class]] &&
        ![view isKindOfClass: [NSToolbarView class]])
        [self layoutTrafficLights];
}

- (void) layoutTrafficLights {
    static BOOL layingOut = NO;
    if (layingOut)
        return;

    NSRect bar = [self _titleBarRect];
    if (NSIsEmptyRect(bar))
        return;

    layingOut = YES;
    for (NSInteger i = 0; i < 3; i++) {
        NSButton *button = [[self window] standardWindowButton: i];
        if (button == nil)
            continue;
        if ([button superview] != self)
            [self addSubview: button];
        NSRect newFrame = [self _trafficLightRectAtIndex: i inTitleBar: bar];
        if (!NSEqualRects([button frame], newFrame))
            [button setFrame: newFrame];
    }
    layingOut = NO;
}

- (void) _keyStateChanged: (NSNotification *) note {
    [self setNeedsDisplay: YES];
    for (NSView *view in _subviews)
        [view setNeedsDisplay: YES];
}

- (void) viewDidMoveToWindow {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver: self];
    if ([self window] != nil) {
        [center addObserver: self selector: @selector(_keyStateChanged:)
                       name: NSWindowDidBecomeKeyNotification object: [self window]];
        [center addObserver: self selector: @selector(_keyStateChanged:)
                       name: NSWindowDidResignKeyNotification object: [self window]];
    }
    [super viewDidMoveToWindow];
}

- (NSWindowBorderType) windowBorderType {
    return _borderType;
}

- (void) setWindowBorderType: (NSWindowBorderType) borderType {
    _borderType = borderType;
    [self setNeedsDisplay: YES];
}

- (NSColor *) _borderColorForNSShowAllViews {
    return [NSColor yellowColor];
}

- (void) drawRect: (NSRect) rect {
    NSRect bounds = [self bounds];
    CGFloat cheatSheet = 0;

    if ([[self window] backgroundColor] != nil) {
        [[[self window] backgroundColor] setFill];
        NSRectFill(rect);
    }

    switch (_borderType) {
    case NSNoBorder:
        break;

    case NSWindowToolTipBorderType:
        [[NSColor colorWithCalibratedWhite: 0.5 alpha: 1.0] setStroke];
        NSFrameRect(bounds);
        bounds = NSInsetRect(bounds, 1, 1);
        cheatSheet = 1;
        break;

    case NSWindowSheetBorderType:
        NSDrawButton(bounds, bounds);
        bounds = NSInsetRect(bounds, 2, 2);
        cheatSheet = 2;
        break;
    }

    if ([[self window] isSheet])
        bounds.size.height += cheatSheet;

    if ([self _themedStyleMask] & NSWindowStyleMaskTitled) {
        NSRect bar = [self _titleBarRect];
        if (!NSIsEmptyRect(bar) && NSIntersectsRect(bar, rect))
            [self _drawTitleBar: bar];
    }
}


/* Title-bar geometry.  AppKit reserves the space above the content view for
 * the frame, so the bar is whatever is left between the highest subview and
 * the top of the frame. */
- (NSRect) _titleBarRect {
    NSRect bounds = [self bounds];
    CGFloat top = NSMinY(bounds);
    BOOL sawSubview = NO;

    for (NSView *view in _subviews) {
        if ([view isHidden])
            continue;
        if ([view isKindOfClass: [NSThemeFrameButton class]])
            continue;
        NSRect frame = [view frame];
        if (!sawSubview || NSMaxY(frame) > top)
            top = NSMaxY(frame);
        sawSubview = YES;
    }

    if (!sawSubview || top >= NSMaxY(bounds))
        return NSZeroRect;

    return NSMakeRect(NSMinX(bounds), top, NSWidth(bounds),
                      NSMaxY(bounds) - top);
}

- (NSWindowStyleMask) _themedStyleMask {
    return [[self window] styleMask] &
           (NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView);
}

- (NSRect) _trafficLightRectAtIndex: (NSInteger) index
                         inTitleBar: (NSRect) bar {
    static const CGFloat diameter = 12.0;
    static const CGFloat spacing = 20.0;
    CGFloat x = NSMinX(bar) + 21.0 + index * spacing;
    return NSMakeRect(x, NSMidY(bar) - diameter / 2.0, diameter, diameter);
}

- (NSInteger) _trafficLightIndexAtPoint: (NSPoint) point {
    NSRect bar = [self _titleBarRect];
    if (NSIsEmptyRect(bar) ||
        !([self _themedStyleMask] & NSWindowStyleMaskTitled))
        return -1;

    for (NSInteger i = 0; i < 3; i++) {
        if (NSPointInRect(point, NSInsetRect(
                                  [self _trafficLightRectAtIndex: i
                                                      inTitleBar: bar],
                                  -4, -4)))
            return i;
    }
    return -1;
}

- (void) _drawTitleBar: (NSRect) bar {
    /* macOS 11+ style: light bar, a hairline, and the three traffic lights,
     * with the title centred unless it would overlap them. */
    [[NSColor colorWithCalibratedWhite: 0.93 alpha: 1.0] setFill];
    NSRectFill(bar);
    [[NSColor colorWithCalibratedWhite: 0.78 alpha: 1.0] setFill];
    NSRectFill(NSMakeRect(NSMinX(bar), NSMinY(bar), NSWidth(bar), 1.0));

    NSString *title = [[self window] title];
    if ([title length] == 0)
        return;

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize: 13.0],
        NSForegroundColorAttributeName:
                [NSColor colorWithCalibratedWhite:
                                 ([[self window] isKeyWindow] ? 0.25 : 0.55)
                                           alpha: 1.0],
    };
    NSSize size = [title sizeWithAttributes: attributes];
    CGFloat left = NSMaxX([self _trafficLightRectAtIndex: 2 inTitleBar: bar]) + 10.0;
    CGFloat x = NSMidX(bar) - size.width / 2.0;
    if (x < left)
        x = left;
    if (x + size.width > NSMaxX(bar) - 10.0)
        return;
    [title drawAtPoint: NSMakePoint(x, NSMidY(bar) - size.height / 2.0)
        withAttributes: attributes];
}

- (void) resizeSubviewsWithOldSize: (NSSize) oldSize {
    NSView *menuView = nil;
    NSToolbarView *toolbarView = nil;
    // The subview that holds the window's content view (the content view
    // itself, or a wrapper around it). Apps may add their own subviews here,
    // after the content view; those are not the content.
    NSView *contentView = [[self window] contentView];
    while ([contentView superview] != nil && [contentView superview] != self)
        contentView = [contentView superview];
    if ([contentView superview] != self)
        contentView = nil;

    // tile the subviews, when/if we add titlebars and such do it here
    for (NSView *view in _subviews) {
        if ([view isKindOfClass: [NSThemeFrameButton class]])
            continue;
        if ([view isKindOfClass: [NSMenuView class]])
            menuView = view;
        else if ([view isKindOfClass: [NSToolbarView class]])
            toolbarView = (NSToolbarView *) view;
    }

    // Any other subview follows its own autoresizing mask.
    for (NSView *view in [[_subviews copy] autorelease]) {
        if (view != contentView && view != menuView && view != toolbarView &&
            ![view isKindOfClass: [NSThemeFrameButton class]])
            [view resizeWithOldSuperviewSize: oldSize];
    }

    // subtracts menu height but not toolbar height
    NSRect contentFrame = [[[self window] class]
            contentRectForFrameRect: [self bounds]
                          styleMask: [[self window] styleMask]];

    // If the class thinks there is a menu but the instance does not want an
    // instance we need to add the menu height back to the content view as
    // contentRectForFrameRect subtracts it

    if ([[[self window] class]
                hasMainMenuForStyleMask: [[self window] styleMask]]) {
        if (![[self window] hasMainMenu])
            contentFrame.size.height += [NSMainMenuView menuHeight];
    }

    NSRect menuFrame = (menuView != nil) ? [menuView frame] : NSZeroRect;
    NSRect toolbarFrame =
            (toolbarView != nil) ? [toolbarView frame] : NSZeroRect;

    menuFrame.origin.y = NSMaxY(contentFrame);
    menuFrame.origin.x = contentFrame.origin.x;
    menuFrame.size.width = contentFrame.size.width;
    [menuView setFrame: menuFrame];

    toolbarFrame.origin.y = NSMaxY(contentFrame) - toolbarFrame.size.height;
    toolbarFrame.origin.x = contentFrame.origin.x;
    toolbarFrame.size.width = contentFrame.size.width;

    [toolbarView setFrame: toolbarFrame];
    [toolbarView layoutViews];

    contentFrame.size.height -= toolbarFrame.size.height;

    /* The title bar lives above the content; the window's frame conversion
     * reserves the extra height, so take it out of the content view here. */
    CGFloat titleHeight = [NSThemeFrame titleBarHeightForStyleMask:
                                            [[self window] styleMask]];
    if (titleHeight > 0.0 && contentFrame.size.height > titleHeight) {
        contentFrame.size.height -= titleHeight;
        contentFrame.origin.y += titleHeight;
    }

    [contentView setFrame: contentFrame];
    [self layoutTrafficLights];
}

- (void) mouseDown: (NSEvent *) event {
    NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
    NSInteger light = [self _trafficLightIndexAtPoint: point];
    if (light == 0) {
        [[self window] performClose: self];
        return;
    } else if (light == 1) {
        [[self window] miniaturize: self];
        return;
    } else if (light == 2) {
        [[self window] zoom: self];
        return;
    }

    if (![[self window] isMovableByWindowBackground])
        return;

    NSPoint origin = [[self window] frame].origin;
    NSPoint firstLocation =
            [[self window] convertBaseToScreen: [event locationInWindow]];
    do {
        event = [[self window] nextEventMatchingMask: NSLeftMouseUpMask |
                                                      NSLeftMouseDraggedMask];

        NSPoint delta =
                [[self window] convertBaseToScreen: [event locationInWindow]];

        delta.x -= firstLocation.x;
        delta.y -= firstLocation.y;

        [[self window] setFrameOrigin: NSMakePoint(origin.x + delta.x,
                                                   origin.y + delta.y)];

    } while ([event type] != NSLeftMouseUp);
}

@end
