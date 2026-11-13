// WebWrapScrollView is a WebKit-internal class, not public AppKit API (it is absent from
// Apple's AppKit documentation), and Dictionary.app defines it itself, as a subclass that
// relies on NSScrollView for -setAllowedPocketEdges:. AppKit must not register a class of
// that name (the runtime reports a duplicate when the app loads) and an NSScrollView
// subclass must answer the pocket-edge messages the app's nib sends.
#import <AppKit/AppKit.h>
#include <stdlib.h>

@interface PocketScrollView : NSScrollView
@end
@implementation PocketScrollView
@end

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        expect(NSClassFromString(@"WebWrapScrollView") == Nil, @"AppKit defines WebWrapScrollView");

        PocketScrollView *view = [[[PocketScrollView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)] autorelease];
        expect([view respondsToSelector:@selector(setAllowedPocketEdges:)], @"a scroll view subclass answers setAllowedPocketEdges:");
        expect([view allowedPocketEdges] == 0, @"no pocket edges by default");
        [view setAllowedPocketEdges:3];
        expect([view allowedPocketEdges] == 3, @"the value reads back");
        NSLog(@"PASS: no WebWrapScrollView, scroll views keep pocket edges");
    }
    return 0;
}
