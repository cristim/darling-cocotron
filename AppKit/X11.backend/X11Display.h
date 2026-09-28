//
//  X11Display.h
//  AppKit
//
//  Created by Johannes Fortmann on 13.10.08.
//  Copyright 2008 -. All rights reserved.
//

#import <AppKit/NSDisplay.h>
#import <X11/Xlib.h>
#import <X11/Xresource.h>
#import <X11/Xlocale.h>

#ifdef DARLING
#import <CoreFoundation/CFRunLoop.h>
#import <CoreFoundation/CFSocket.h>
#endif

@class X11Cursor;

// X11 has no scale protocol, so the scale is resolved once by the display and
// published through an X11Screen (declared in X11Display.m, like the Wayland
// backend's WaylandScreen). Every window reads it back from the display so a
// screen and a window can never disagree: -[NSWindow backingScaleFactor]
// returns the platform window's value whenever it is finite and positive, which
// would otherwise make the screen fallback dead.
@interface X11Display : NSDisplay {
    Display *_display;
    CGFloat _backingScale;
    int _fileDescriptor;
#ifndef DARLING
    NSSelectInputSource *_inputSource;
#else
    // We use CFRunLoop directly, without going through any Foundation wrapper,
    // because Apple's Cocoa has none. Unlike Apple's Cocoa, we need to watch
    // over a Unix domain socket, not a Mach port.
    CFSocketRef _cfSocket;
    CFRunLoopSourceRef _source;
#endif
    NSMutableDictionary *_windowsByID;

    id lastFocusedWindow;
    // Clicks are grouped per button and per window, so state for the left
    // button cannot make the next middle-button click look like a double click.
    NSMutableDictionary *_buttonClickCounts;
    NSInteger _clickCount;
    Time _lastClickTime;       // X server milliseconds, wraps modulo 2^32.
    unsigned int _lastClickButton;
    XID _lastClickWindow;
    NSPoint _lastClickPoint;   // Logical points, so the radius is scale-independent.
    X11Cursor *_blankCursor, *_defaultCursor;
    BOOL _cursorGrabbed;
    KeySym _lastKeySym;
    // The aggregate modifier mask as of the last key event, so a change that
    // no modifier key reported (a modifier released while another app had the
    // focus) is still noticed and corrected with a keycode-less flagsChanged.
    NSEventModifierFlags _modifierFlags;
    int _rrEventBase;
    NSArray* _lastScreens;

@public
    XIM _xim;
}

- (Display *) display;

// Device pixels per logical point. X11 exposes no scale, so this reads
// DARLING_X11_SCALE, then GDK_SCALE (the X11 convention, already exported by
// common desktop configs), and otherwise stays 1.0. A panel's physical size is
// deliberately not used: it reports panel DPI, not scale, so it reads 1.0 on a
// HiDPI 4K panel and 2.0 on a 1x laptop.
- (CGFloat) backingScale;

- (void) setWindow: (id) window forID: (XID) i;

- (CGFloat) doubleClickInterval;
- (int) handleError: (XErrorEvent *) errorEvent;
@end
