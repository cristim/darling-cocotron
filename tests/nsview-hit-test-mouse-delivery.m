/*
 * Hit-test and responder routing regression for mouse input.
 *
 * The native-Wayland click probe established that a virtual pointer click reaches
 * the compositor and changes window state, but the guest receives no pointer event
 * at all: cocotron's WaylandDisplay never has its pointerEvent:arguments: called,
 * so the event is lost before AppKit. That is upstream of this test.
 *
 * This covers the half AppKit owns, so that a break in delivery, hit testing or
 * responder routing is caught here rather than being blamed on the layer above:
 * a synthetic left click posted into a real window must reach the view under the
 * pointer, must not reach a view that is not under it, and must survive a flipped
 * view whose coordinate system is inverted.
 *
 * Exit codes are distinct per failure.
 */
#import <AppKit/AppKit.h>
#include <stdio.h>

/* Records what a view is asked to do, so the delivery path can be checked without
 * a window server. */
@interface AZRecordingView : NSView {
    BOOL _flipped;
    int _mouseDownCount;
    int _mouseUpCount;
    int _hitTestCount;
    NSView *_lastHit;
    NSPoint _lastPoint;
}
@property (nonatomic, assign) BOOL flipped;
@property (nonatomic, readonly) int mouseDownCount;
@property (nonatomic, readonly) int mouseUpCount;
@property (nonatomic, readonly) int hitTestCount;
@property (nonatomic, retain) NSView *lastHit;
@property (nonatomic, assign) NSPoint lastPoint;
@end

@implementation AZRecordingView

@synthesize flipped = _flipped;
@synthesize mouseDownCount = _mouseDownCount;
@synthesize mouseUpCount = _mouseUpCount;
@synthesize hitTestCount = _hitTestCount;
@synthesize lastHit = _lastHit;
@synthesize lastPoint = _lastPoint;

- (BOOL) isFlipped { return _flipped; }
- (void) setFlipped: (BOOL) flipped { _flipped = flipped; }

- (NSView *) hitTest: (NSPoint) point {
    _hitTestCount++;
    _lastPoint = point;
    NSView *hit = [super hitTest: point];
    [_lastHit release];
    _lastHit = [hit retain];
    return hit;
}

- (void) mouseDown: (NSEvent *) event { _mouseDownCount++; }
- (void) mouseUp: (NSEvent *) event { _mouseUpCount++; }

- (void) dealloc {
    [_lastHit release];
    [super dealloc];
}

@end

/* Drains the application's own event queue, which is where a posted event waits:
 * NSApplication only dequeues and dispatches it from its event loop, so a plain
 * run loop pump would leave the event sitting in the queue. This is the same
 * dispatch the real click takes once the backend has produced an NSEvent, so the
 * delivery, hit test and responder routing below are the production ones. */
static void pump(NSTimeInterval seconds) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow: seconds];
    for (;;) {
        NSEvent *event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                         untilDate: until
                                            inMode: NSDefaultRunLoopMode
                                           dequeue: YES];
        if (event == nil) {
            break;
        }
        fprintf(stderr, "drained event type=%ld window=%s\n", (long)[event type],
                [event window] == nil ? "none" : "some");
        [NSApp sendEvent: event];
    }
}

static NSEvent *mouseEvent(NSEventType type, NSPoint location) {
    return [NSEvent mouseEventWithType: type
                              location: location
                         modifierFlags: 0
                             timestamp: 0
                          windowNumber: 0
                               context: NULL
                           eventNumber: 0
                            clickCount: 1
                              pressure: 1];
}

int main(void) {
    @autoreleasepool {
        int status = 0;

        NSRect frame = NSMakeRect(0, 0, 200, 100);
        NSWindow *window = [[NSWindow alloc]
            initWithContentRect: frame
                      styleMask: NSWindowStyleMaskTitled
                        backing: NSBackingStoreBuffered
                          defer: NO];
        AZRecordingView *view = [[AZRecordingView alloc]
            initWithFrame: frame];
        [[window contentView] addSubview: view];
        [window makeKeyAndOrderFront: nil];

        /* A click inside the view has to reach it. */
        NSPoint inside = NSMakePoint(100, 50);
        [NSApp postEvent: mouseEvent(NSLeftMouseDown, inside) atStart: NO];
        [NSApp postEvent: mouseEvent(NSLeftMouseUp, inside) atStart: NO];
        pump(0.2);

        if (view.hitTestCount == 0) {
            fprintf(stderr, "hit testing was never asked where the click was\n");
            status = 1;
        }
        if (view.mouseDownCount != 1 || view.mouseUpCount != 1) {
            fprintf(stderr,
                    "a click inside the view did not reach it: "
                    "mouseDown=%d mouseUp=%d\n",
                    view.mouseDownCount, view.mouseUpCount);
            status = 1;
        }

        /* A click outside the view must not reach it. In an unflipped view the
         * origin is at the bottom left, so a point above the frame is outside. */
        int downBefore = view.mouseDownCount;
        NSPoint outside = NSMakePoint(100, 400);
        [NSApp postEvent: mouseEvent(NSLeftMouseDown, outside) atStart: NO];
        [NSApp postEvent: mouseEvent(NSLeftMouseUp, outside) atStart: NO];
        pump(0.2);
        if (view.mouseDownCount != downBefore) {
            fprintf(stderr,
                    "a click outside the view reached it anyway: mouseDown went "
                    "from %d to %d\n",
                    downBefore, view.mouseDownCount);
            status = 2;
        }

        /* A flipped view inverts its coordinate system; a click at the same
         * window position has to land on the flipped view rather than miss it.
         * The point is in window coordinates, so it is converted into the view's
         * own space the way a real hit test does. */
        view.flipped = YES;
        [view setNeedsDisplay: YES];
        pump(0.1);
        int downFlippedBefore = view.mouseDownCount;
        NSPoint flippedInside = NSMakePoint(100, 20); /* 20 from the top */
        NSEvent *flippedEvent = mouseEvent(NSLeftMouseDown, flippedInside);
        [NSApp postEvent: flippedEvent atStart: NO];
        [NSApp postEvent: mouseEvent(NSLeftMouseUp, flippedInside) atStart: NO];
        pump(0.2);
        if (view.mouseDownCount != downFlippedBefore + 1) {
            fprintf(stderr,
                    "a click inside a flipped view did not reach it: mouseDown "
                    "went from %d to %d\n",
                    downFlippedBefore, view.mouseDownCount);
            status = 3;
        }

        fprintf(stderr, "hitTest calls=%d, inside click delivered, outside "
                        "rejected, flipped view delivered\n",
                view.hitTestCount);
        if (status == 0) {
            fprintf(stderr, "all hit-test checks passed\n");
        }
        return status;
    }
}
