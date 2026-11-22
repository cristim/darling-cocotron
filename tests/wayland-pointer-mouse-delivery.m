/*
 * Mouse delivery regression for the Wayland pointer path.
 *
 * The native click probe showed a virtual pointer click reaching the compositor
 * and changing window state while the guest received nothing. The guest's half of
 * the path is cocotron's Wayland backend: it turns a pointer enter into the window
 * under the pointer, and a pointer button into an NSEvent that
 * -[NSApplication sendEvent:] routes by the event's window.
 *
 * This test drives that production code directly: a synthetic pointer enter for a
 * real window's surface, then a pointer button, and the event has to come out the
 * other end and reach the view under the pointer. It is deliberately the
 * production method rather than a copy of it, so a regression in the backend is
 * caught here.
 *
 * The test declares the two backend methods it calls instead of importing the
 * backend's private header, which pulls in libwayland. The signatures match the
 * implementation, and the argument array is the same union of one word per member.
 *
 * Exit codes are distinct per failure.
 */
#import <AppKit/AppKit.h>
#include <stdio.h>

/* The pointer argument union, mirrored: one word per member, and a fixed point is
 * 24.8, so it converts by multiplying by 256 to make a double. */
typedef union {
    int32_t i;
    uint32_t u;
    const void *o;
    float f;
    double d;
} AZPointerArgument;

static const uint32_t AZPointerEnter = 0;
static const uint32_t AZPointerButton = 3;
static const uint32_t AZPointerButtonStatePressed = 1;
static const uint32_t AZPointerButtonStateReleased = 0;
static const uint32_t AZButtonLeft = 0x110; /* BTN_LEFT, linux input-event-codes */

static CGFloat AZFixed(CGFloat value) { return value * 256.0f; }

/* The two backend entry points, declared as implemented. */
@interface NSObject (AZBackendPointer)
- (id) windowForSurface: (const void *) surface;
- (void) pointerEvent: (uint32_t) opcode arguments: (AZPointerArgument *) args;
- (void) postEvent: (NSEvent *) event atStart: (BOOL) atStart;
@end

/* A window's surface, as the backend holds it. */
@interface NSWindow (AZWindowSurface)
- (const void *) surface;
@end

@interface AZClickRecordingView : NSView {
    int _mouseDownCount;
    int _mouseUpCount;
    BOOL _flipped;
}
@property (nonatomic, readonly) int mouseDownCount;
@property (nonatomic, readonly) int mouseUpCount;
@property (nonatomic, assign) BOOL flipped;
@end

@implementation AZClickRecordingView
@synthesize mouseDownCount = _mouseDownCount;
@synthesize mouseUpCount = _mouseUpCount;
@synthesize flipped = _flipped;
- (BOOL) isFlipped { return _flipped; }
- (void) mouseDown: (NSEvent *) event { _mouseDownCount++; }
- (void) mouseUp: (NSEvent *) event { _mouseUpCount++; }
@end

/* The backend instance the app is using. */
static id AZCurrentDisplay(void) {
    Class displayClass = NSClassFromString(@"WaylandDisplay");
    if (displayClass == Nil) {
        return nil;
    }
    return [NSDisplay performSelector: NSSelectorFromString(@"currentDisplay")];
}

/* Drains the application queue, which is where a produced event waits. */
static void AZPump(NSTimeInterval seconds) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow: seconds];
    for (;;) {
        NSEvent *event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                         untilDate: until
                                            inMode: NSDefaultRunLoopMode
                                           dequeue: YES];
        if (event == nil) {
            break;
        }
        [NSApp sendEvent: event];
    }
}

/* Sends a pointer enter for the window's surface, then a left button press and
 * release at a surface-local point. */
static int AZClickAt(id display, NSWindow *window, CGPoint surfacePoint) {
    AZPointerArgument enter[4] = {0};
    enter[0].u = 1; /* serial */
    enter[1].o = [window surface];
    enter[2].f = AZFixed(surfacePoint.x);
    enter[3].f = AZFixed(surfacePoint.y);
    [display pointerEvent: AZPointerEnter arguments: enter];

    AZPointerArgument down[4] = {0};
    down[0].u = 2; /* serial */
    down[1].u = 1000; /* time */
    down[2].u = AZButtonLeft;
    down[3].u = AZPointerButtonStatePressed;
    [display pointerEvent: AZPointerButton arguments: down];

    AZPointerArgument up[4] = {0};
    up[0].u = 3; /* serial */
    up[1].u = 1100; /* time */
    up[2].u = AZButtonLeft;
    up[3].u = AZPointerButtonStateReleased;
    [display pointerEvent: AZPointerButton arguments: up];
    return 0;
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
        AZClickRecordingView *view = [[AZClickRecordingView alloc]
            initWithFrame: frame];
        [[window contentView] addSubview: view];
        [window makeKeyAndOrderFront: nil];
        AZPump(0.3);

        id display = AZCurrentDisplay();
        if (display == nil) {
            fprintf(stderr, "the Wayland backend is not in use; run with "
                            "DARLING_APPKIT_BACKEND=wayland and a compositor\n");
            return 1;
        }
        if ([window surface] == NULL) {
            fprintf(stderr, "the window has no surface, so the pointer path "
                            "cannot be exercised\n");
            return 1;
        }

        /* A click in the middle of the window has to reach the view. */
        AZClickAt(display, window, CGPointMake(100, 50));
        AZPump(0.3);
        fprintf(stderr, "after a click in the middle: mouseDown=%d mouseUp=%d\n",
                view.mouseDownCount, view.mouseUpCount);
        if (view.mouseDownCount != 1 || view.mouseUpCount != 1) {
            fprintf(stderr,
                    "a click inside the window did not reach the view: "
                    "mouseDown=%d mouseUp=%d (expected 1 and 1)\n",
                    view.mouseDownCount, view.mouseUpCount);
            status = 1;
        }

        /* A click outside the view, below it, must not reach it. */
        int downBefore = view.mouseDownCount;
        AZClickAt(display, window, CGPointMake(100, 400));
        AZPump(0.3);
        if (view.mouseDownCount != downBefore) {
            fprintf(stderr,
                    "a click outside the view reached it: mouseDown went from "
                    "%d to %d\n",
                    downBefore, view.mouseDownCount);
            status = 2;
        }

        /* A flipped view inverts its coordinate system, so a point 20 from the
         * surface's top edge has to land on the view, not miss it. */
        view.flipped = YES;
        [view setNeedsDisplay: YES];
        AZPump(0.2);
        int downFlippedBefore = view.mouseDownCount;
        AZClickAt(display, window, CGPointMake(100, 20));
        AZPump(0.3);
        if (view.mouseDownCount != downFlippedBefore + 1) {
            fprintf(stderr,
                    "a click inside a flipped view did not reach it: mouseDown "
                    "went from %d to %d\n",
                    downFlippedBefore, view.mouseDownCount);
            status = 3;
        }

        if (status == 0) {
            fprintf(stderr, "all pointer delivery checks passed\n");
        }
        return status;
    }
}
