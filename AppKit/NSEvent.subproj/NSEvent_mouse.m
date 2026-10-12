/* Copyright (c) 2006-2007 Christopher J. W. Lloyd <cjwl@objc.net>
                 2010 Markus Hitter <mah@jump-ing.de>

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
#import <AppKit/NSEvent_mouse.h>
#import <CoreGraphics/CGEvent.h>

@interface NSObject (MouseCGEventFlags)
- (void)setFlags:(CGEventFlags)flags;
@end

@implementation NSEvent_mouse

- (instancetype) initWithType: (NSEventType) type
                     location: (NSPoint) location
                modifierFlags: (NSEventModifierFlags) modifierFlags
                       window: (NSWindow *) window
                   clickCount: (NSInteger) clickCount
                       deltaX: (CGFloat) deltaX
                       deltaY: (CGFloat) deltaY
{
    [super initWithType: type
                 location: location
            modifierFlags: modifierFlags
                   window: window];

    _buttonNumber = (type == NSRightMouseDown || type == NSRightMouseUp || type == NSRightMouseDragged) ? 1 :
        (type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSOtherMouseDragged) ? 2 : 0;
    _clickCount = clickCount;
    _deltaX = deltaX;
    _deltaY = deltaY;

    return self;
}

- (NSInteger) clickCount {
    return _clickCount;
}

- (short) subtype {
    // Ordinary mouse events use NSMouseEventSubtype (0). The base method
    // raises for event classes that do not have a subtype; Chromium queries
    // this before forwarding every mouse event to its renderer.
    return 0;
}

- (instancetype) initWithType: (NSEventType) type
                     location: (NSPoint) location
                modifierFlags: (NSEventModifierFlags) modifierFlags
                       window: (NSWindow *) window
                       deltaY: (CGFloat) deltaY
{
    [super initWithType: type
                 location: location
            modifierFlags: modifierFlags
                   window: window];

    _deltaY = deltaY;

    return self;
}

- (instancetype) initWithType: (NSEventType) type
                     location: (NSPoint) location
                modifierFlags: (NSEventModifierFlags) modifierFlags
                    timestamp: (NSTimeInterval) timestamp
                 windowNumber: (NSInteger) windowNumber
                      context: (NSGraphicsContext *) context
                  eventNumber: (NSInteger) eventNumber
               trackingNumber: (NSInteger) tracking
                     userData: (void *) userData
{
    self = [super initWithType: type
                      location: location
                 modifierFlags: modifierFlags
                        window: (id) windowNumber];
    if (self != nil) {
        _trackingNumber = tracking;
        _userData = userData;
    }
    return self;
}

- (instancetype) initWithType: (NSEventType) type
                     location: (NSPoint) location
                modifierFlags: (NSEventModifierFlags) modifierFlags
                    timestamp: (NSTimeInterval) timestamp
                 windowNumber: (NSInteger) windowNumber
                      context: (NSGraphicsContext *) context
                  eventNumber: (NSInteger) eventNumber
                   clickCount: (NSInteger) clickCount
                     pressure: (float) pressure
{
    [super initWithType: type
                 location: location
            modifierFlags: modifierFlags
                   window: (id) windowNumber];
    _buttonNumber = (type == NSRightMouseDown || type == NSRightMouseUp || type == NSRightMouseDragged) ? 1 :
        (type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSOtherMouseDragged) ? 2 : 0;
    _clickCount = clickCount;
    return self;
}

- (CGFloat) deltaX {
    return _deltaX;
}

- (CGFloat) deltaY {
    return _deltaY;
}

- (CGFloat) deltaZ {
    return 0.0;
}

// X11 wheel buttons are discrete mouse-wheel notches, without trackpad
// gesture phases or momentum. Chromium queries these before forwarding them.
- (NSUInteger) phase { return 0; }
- (NSUInteger) momentumPhase { return 0; }
- (BOOL) hasPreciseScrollingDeltas { return NO; }
- (BOOL) isDirectionInvertedFromDevice { return NO; }
- (CGFloat) scrollingDeltaX { return _deltaX; }
- (CGFloat) scrollingDeltaY { return _deltaY; }

- (CGEventRef) CGEvent {
    if (_type != NSScrollWheel) {
        switch (_type) {
        case NSLeftMouseDown: case NSLeftMouseUp: case NSRightMouseDown: case NSRightMouseUp:
        case NSMouseMoved: case NSLeftMouseDragged: case NSRightMouseDragged:
        case NSOtherMouseDown: case NSOtherMouseUp: case NSOtherMouseDragged: {
            CGEventRef event = CGEventCreateMouseEvent(NULL, (CGEventType)_type,
                NSPointToCGPoint([self locationInWindow]), (CGMouseButton)_buttonNumber);
            CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber, _buttonNumber);
            CGEventSetIntegerValueField(event, kCGMouseEventClickState, _clickCount);
            [(id)event setFlags:(CGEventFlags)[self modifierFlags]];
            return (CGEventRef)[(id)event autorelease];
        }
        default: return NULL;
        }
    }
    CGEventRef event = CGEventCreateScrollWheelEvent(NULL,
        kCGScrollEventUnitLine, 2, (int32_t)_deltaY, (int32_t)_deltaX);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventIsContinuous, 0);
    return (CGEventRef)[(id)event autorelease];
}

// Apple's documentation is a bit confusing here. NSEvent exposes no API to pass
// a NSTrackingArea object on creation, yet they expose API to get that pointer.
// Additionally, they state -trackingArea would deliver meaningful returns only
// if the area was created with the NSTrackingArea API.
//
// On the other hand, NSTrackingArea's docs explicitely state a pointer to a
// NSTrackingArea is now substitute for NSTrackingRectTags, which are in turn
// "trackingNumbers". See "Compatibility Issues", there.
//
// Accordingly, it's unclear wether there's a difference between -trackingArea
// and -trackingNumber at all (as of 10.6 docs). Let's assume they are the same.
- (NSTrackingArea *) trackingArea {
    return (NSTrackingArea *) _trackingNumber;
}

- (NSInteger) trackingNumber {
    return _trackingNumber;
}

- (void *) userData {
    if (_type != NSMouseEntered && _type != NSMouseExited) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"-[%@ userData] not valid for type %d",
                            [self class], _type];
        return NULL;
    }

    return _userData;
}

- (NSInteger) buttonNumber {
    return _buttonNumber;
}

- (void) _setButtonNumber: (NSInteger) num {
    _buttonNumber = num;
}

@end
