/* Copyright (c) 2026 Darling Developers

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. */

#import <AppKit/NSMenuToolbarItem.h>
#import <AppKit/NSToolbar.h>
#import <AppKit/NSMenu.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSColor.h>
#import "NSToolbar.subproj/NSToolbarItemView.h"
#import <Foundation/NSDate.h>

@interface NSToolbarItem (NSMenuToolbarItemPrivate)
- (void)_didChange;
- (void)drawInRect: (NSRect)bounds highlighted: (BOOL)highlighted;
- (NSSize)sizeForSizeMode: (NSToolbarSizeMode)sizeMode
             displayMode: (NSToolbarDisplayMode)displayMode
                 minSize: (NSSize)minSize maxSize: (NSSize)maxSize;
@end

@implementation NSMenuToolbarItem

- (void)validate {
    // A menu-only item has no primary action for superclass validation to
    // resolve. Preserve its explicit enabled state; menu entries validate when
    // the menu opens. Action-bearing items use ordinary toolbar validation.
    if ([self action] != NULL)
        [super validate];
}

- (NSRect)_menuIndicatorRectForBounds: (NSRect)bounds {
    if (!_showsIndicator || NSWidth(bounds) <= 0 || NSHeight(bounds) <= 0)
        return NSZeroRect;
    CGFloat width = MIN(12, NSWidth(bounds));
    return NSMakeRect(NSMaxX(bounds) - width, NSMinY(bounds), width,
                      NSHeight(bounds));
}

- (NSSize)sizeForSizeMode: (NSToolbarSizeMode)sizeMode
             displayMode: (NSToolbarDisplayMode)displayMode
                 minSize: (NSSize)minSize maxSize: (NSSize)maxSize {
    NSSize contentMin = minSize, contentMax = maxSize;
    if (_showsIndicator) {
        contentMin.width = MAX(0, minSize.width - 12);
        contentMax.width = MAX(0, maxSize.width - 12);
    }
    NSSize size = [super sizeForSizeMode: sizeMode displayMode: displayMode
                               minSize: contentMin maxSize: contentMax];
    if (_showsIndicator) {
        size.width += 12;
        // Zero is the superclass's unconstrained-size sentinel. In particular,
        // a maximum smaller than the indicator must still constrain the total.
        if (maxSize.width > 0)
            size.width = MIN(size.width, maxSize.width);
    }
    return size;
}

- (void)drawInRect: (NSRect)bounds highlighted: (BOOL)highlighted {
    NSRect indicator = [self _menuIndicatorRectForBounds: bounds];
    NSRect content = bounds;
    content.size.width -= NSWidth(indicator);
    [super drawInRect: content highlighted: highlighted];
    if (NSIsEmptyRect(indicator))
        return;
    [[self isEnabled] ? [NSColor controlTextColor]
                      : [NSColor disabledControlTextColor] set];
    CGFloat x = NSMidX(indicator), y = NSMidY(indicator);
    CGFloat radius = MIN(3, NSWidth(indicator) / 4);
    CGFloat halfHeight = MIN(1.5, NSHeight(indicator) / 4);
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint: NSMakePoint(x - radius, y + halfHeight)];
    [arrow lineToPoint: NSMakePoint(x + radius, y + halfHeight)];
    [arrow lineToPoint: NSMakePoint(x, y - halfHeight)];
    [arrow closePath];
    [arrow fill];
    if ([self action] != NULL) {
        CGFloat inset = MIN(2, NSHeight(indicator) / 4);
        NSBezierPath *separator = [NSBezierPath bezierPath];
        [separator moveToPoint: NSMakePoint(NSMinX(indicator), NSMinY(indicator) + inset)];
        [separator lineToPoint: NSMakePoint(NSMinX(indicator), NSMaxY(indicator) - inset)];
        [separator stroke];
    }
}

// Called by the enclosing toolbar view before its ordinary action tracking.
- (BOOL)_trackMenuWithEvent: (NSEvent *) event inView: (NSToolbarItemView *) view {
    if (_trackingMenu || ![self isEnabled])
        return YES;
    id window = [[view window] retain];
    if (window == nil || [view toolbarItem] != self) {
        [window release];
        return YES;
    }
    [self retain];
    [event retain];
    [view retain];
    _trackingMenu = YES;
    @try {
    NSPoint point = [view convertPoint: [event locationInWindow] fromView: nil];
    BOOL indicatorClick = _showsIndicator &&
            NSMouseInRect(point, [self _menuIndicatorRectForBounds: [view bounds]],
                          [view isFlipped]);
    if ([self action] != NULL && !indicatorClick) {
        // Leave a quick release/drag queued for the ordinary toolbar action
        // loop. Holding without either event opens the item's menu instead.
        NSEvent *next = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
                                         untilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]
                                            inMode: NSEventTrackingRunLoopMode
                                           dequeue: NO];
        if (![self isEnabled] || [view window] != window ||
            [view toolbarItem] != self)
            return YES;
        if (next != nil)
            return NO;
    }
    NSMenu *menu = [_menu retain];
    @try {
        [NSMenu popUpContextMenu: menu withEvent: event forView: view];
    } @finally {
        [menu release];
    }
    return YES;
    } @finally {
        _trackingMenu = NO;
        [window release];
        [view release];
        [event release];
        [self release];
    }
}

- (instancetype)initWithItemIdentifier: (NSToolbarItemIdentifier) identifier {
    if ((self = [super initWithItemIdentifier: identifier])) {
        _menu = [[NSMenu alloc] initWithTitle: @""];
        _showsIndicator = YES;
    }
    return self;
}

- (id)copyWithZone: (NSZone *) zone {
    NSMenuToolbarItem *copy = [super copyWithZone: zone];
    copy->_menu = [_menu retain];
    copy->_trackingMenu = NO;
    return copy;
}

- (NSMenuItem *)menuFormRepresentation {
    NSMenuItem *item = [super menuFormRepresentation];
    [item setSubmenu: _menu];
    return item;
}

- (void)dealloc {
    [_menu release];
    [super dealloc];
}

- (void)setMenu: (NSMenu *) menu {
    if (menu == _menu)
        return;
    NSMenu *replacement = menu ? [menu retain] : [[NSMenu alloc] initWithTitle: @""];
    NSMenu *previous = _menu;
    _menu = replacement;
    [_menuFormRepresentation setSubmenu: _menu];
    [previous release];
    [self _didChange];
}

- (void)setShowsIndicator: (BOOL) showsIndicator {
    if (_showsIndicator == showsIndicator)
        return;
    _showsIndicator = showsIndicator;
    [self _didChange];
}

@synthesize menu = _menu;
@synthesize showsIndicator = _showsIndicator;

@end
