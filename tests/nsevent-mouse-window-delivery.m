#import <AppKit/AppKit.h>
#include <stdio.h>

/* A mouse event names one NSWindow, and that is how it is delivered:
 * -[NSEvent initWithType:...window:] keeps only the window's number, and
 * -[NSApplication sendEvent:] sends the event to whatever -[NSEvent window]
 * resolves that number to.
 *
 * This matters for the Wayland backend, which builds its events from a
 * WaylandWindow, a CGWindow that holds the surface and whose delegate is the
 * NSWindow the event belongs to. The backend passes that delegate, which is
 * correct: it is the one object that is an NSWindow and can answer
 * -windowNumber. Naming the WaylandWindow instead would leave the event with no
 * window to deliver to.
 *
 * The cocotron test runner only reaches the "no window server" path, so this is
 * run against the running display with notes/run-nsevent-mouse-window-delivery.sh.
 */

@interface AZDeliveryView : NSView {
    NSUInteger _clicks;
}
@property (nonatomic, assign) NSUInteger clicks;
@end

@implementation AZDeliveryView
- (void) mouseDown: (NSEvent *) event { _clicks++; }
- (void) mouseUp: (NSEvent *) event { }
@end

/* The same view, flipped, to show delivery does not depend on the flip. */
@interface AZFlippedView : AZDeliveryView
@end

@implementation AZFlippedView
- (BOOL) isFlipped { return YES; }
@end

static void AZPump(NSTimeInterval seconds) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: seconds];
    while ([deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                 beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
}

static NSEvent *AZMouseEvent(NSEventType type, NSWindow *window, NSPoint location) {
    return [NSEvent mouseEventWithType: type
                              location: location
                         modifierFlags: 0
                                window: window
                            clickCount: 1
                                deltaX: 0.0
                                deltaY: 0.0];
}

static void AZClick(NSWindow *window, NSPoint location) {
    [NSApp postEvent: AZMouseEvent(NSLeftMouseDown, window, location) atStart: NO];
    [NSApp postEvent: AZMouseEvent(NSLeftMouseUp, window, location) atStart: NO];
    AZPump(0.2);
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
        AZDeliveryView *view = [[AZDeliveryView alloc] initWithFrame: frame];
        [[window contentView] addSubview: view];
        [window makeKeyAndOrderFront: nil];
        AZPump(0.3);

        /* The event keeps the window it was built with. */
        NSEvent *probe = AZMouseEvent(NSLeftMouseDown, window, NSMakePoint(100, 50));
        if ([probe window] != window) {
            fprintf(stderr, "the event did not keep the window it was built with\n");
            return 1;
        }

        /* A click inside the view reaches it. */
        [view setClicks: 0];
        AZClick(window, NSMakePoint(100, 50));
        if ([view clicks] != 1) {
            fprintf(stderr, "a click inside the view did not reach it\n");
            status = 1;
        }

        /* A click outside the view does not. */
        AZClick(window, NSMakePoint(100, 400));
        if ([view clicks] != 1) {
            fprintf(stderr, "a click outside the view reached it\n");
            status = 1;
        }

        /* A flipped view is delivered to the same way. */
        AZFlippedView *flipped = [[AZFlippedView alloc] initWithFrame: frame];
        [flipped setClicks: 0];
        [[window contentView] addSubview: flipped];
        AZPump(0.2);
        AZClick(window, NSMakePoint(100, 20));
        if ([flipped clicks] != 1) {
            fprintf(stderr, "a click in a flipped view did not reach it\n");
            status = 1;
        }

        if (status == 0)
            printf("all pointer delivery checks passed\n");
        return status;
    }
}
