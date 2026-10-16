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
#import "X11RelativeMouse.h"

#ifdef DARLING
#import <CoreFoundation/CFRunLoop.h>
#import <CoreFoundation/CFSocket.h>
#endif

@class X11Cursor, X11Window;

@interface X11Display : NSDisplay {
    Display *_display;
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
    NSTimeInterval lastClickTimeStamp;
    int clickCount;
    X11Cursor *_blankCursor, *_defaultCursor;
    /* Relative mouse mode: requested by CGAssociateMouseAndMouseCursorPosition(false); _relativeMouse.active
     * while its pointer grab on _relativeWindow is held (released on focus loss, retaken on focus). */
    BOOL _relativeRequested;
    Window _relativeWindow;
    X11RelativeMouse _relativeMouse;
    BOOL _isXwayland;
    /* The cursor last defined by setCursor:, retained so its X id cannot be freed and reused while cached. */
    Window _definedCursorWindow;
    X11Cursor *_definedCursor;
    BOOL _cursorHidden;
    Window _confinedWindow;
    int _confinedWidth;
    int _confinedHeight;
    unsigned int _otherButtonsDown;
    KeySym _lastKeySym;
    unsigned char _modifierKeysDown[256];
    int _rrEventBase;
    NSArray* _lastScreens;
    // Root-window rectangle of the primary monitor (macOS's global origin).
    NSRect _primaryRootFrame;
    BOOL _primaryRootFrameValid;

@public
    XIM _xim;
}

- (void) updateMouseConfinementForWindow:(X11Window *)window;
- (Display *) display;
- (BOOL) activateProcessIdentifier: (pid_t) processIdentifier;

- (void) setWindow: (id) window forID: (XID) i;

- (CGFloat) doubleClickInterval;
- (int) handleError: (XErrorEvent *) errorEvent;

// Conversions between X root coordinates (top-left of the root window, y down)
// and Cocoa global coordinates (bottom-left of the primary screen, y up).
- (NSRect) rootRectForFrame: (NSRect) frame;
- (NSRect) frameForRootRect: (NSRect) rect;
@end
