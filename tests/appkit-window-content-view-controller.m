// NSWindow and NSWindowController contentViewController, as Apple documents them: the controller's
// view becomes the content view, the window takes its size, and setting a content view clears it.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static BOOL trackedDeallocated;

@interface TrackedViewController : NSViewController
@end
@implementation TrackedViewController
- (void)dealloc
{
    trackedDeallocated = YES;
    [super dealloc];
}
@end

@interface ViewlessViewController : NSViewController
@end
@implementation ViewlessViewController
- (void)loadView
{
}
@end

static NSViewController *controllerWithSize(CGFloat width, CGFloat height)
{
    NSViewController *controller = [[[NSViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    controller.view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)] autorelease];
    return controller;
}

int main(void)
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES];
        expect(window.contentViewController == nil, @"no content view controller by default");

        NSViewController *first = controllerWithSize(320, 200);
        window.contentViewController = first;
        expect(window.contentViewController == first, @"window keeps its content view controller");
        expect(window.contentView == first.view, @"the controller's view is the content view");
        expect(NSEqualSizes([window.contentView frame].size, NSMakeSize(320, 200)),
               @"the window takes the size of the controller's view");

        NSViewController *second = controllerWithSize(200, 150);
        NSView *firstView = [first.view retain];
        window.contentViewController = second;
        expect(window.contentViewController == second && window.contentView == second.view,
               @"a new controller replaces the previous one");
        expect([firstView superview] == nil, @"the previous controller's view leaves the window");
        [firstView release];

        TrackedViewController *tracked = [[TrackedViewController alloc] initWithNibName:nil bundle:nil];
        tracked.view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)] autorelease];
        window.contentViewController = tracked;
        [tracked release];
        expect(!trackedDeallocated, @"the window keeps its content view controller");
        window.contentViewController = second;
        expect(trackedDeallocated, @"the window releases a replaced controller");

        window.contentViewController = second;
        expect(window.contentViewController == second && window.contentView == second.view,
               @"setting the same controller again keeps it");

        NSView *plain = [[[NSView alloc] initWithFrame:NSZeroRect] autorelease];
        window.contentView = plain;
        expect(window.contentViewController == nil, @"setting a content view clears the controller");

        NSWindowController *windowController = [[NSWindowController alloc] initWithWindow:window];
        NSViewController *third = controllerWithSize(250, 180);
        windowController.contentViewController = third;
        expect(windowController.contentViewController == third && window.contentViewController == third,
               @"the window controller's content view controller is the window's");
        expect(NSEqualSizes([window.contentView frame].size, NSMakeSize(250, 180)),
               @"the controller's size wins over a previous plain content view");
        window.contentViewController = second;
        expect(windowController.contentViewController == second, @"the window controller tracks the window");

        NSWindowController *empty = [[[NSWindowController alloc] initWithWindow:nil] autorelease];
        expect(empty.contentViewController == nil, @"no window, no content view controller");
        BOOL raised = NO;
        @try
        {
            empty.contentViewController = third;
        }
        @catch (NSException *e)
        {
            raised = [e.name isEqualToString:NSInternalInconsistencyException];
        }
        expect(raised, @"setting a content view controller without a window raises");

        NSViewController *viewless = [[[ViewlessViewController alloc] initWithNibName:nil bundle:nil] autorelease];
        raised = NO;
        @try
        {
            window.contentViewController = viewless;
        }
        @catch (NSException *e)
        {
            raised = [e.name isEqualToString:NSInternalInconsistencyException];
        }
        expect(raised && window.contentViewController == second, @"a controller without a view raises and changes nothing");

        [windowController release];
        [window release];
        NSLog(@"PASS: contentViewController");
    }
    return 0;
}
