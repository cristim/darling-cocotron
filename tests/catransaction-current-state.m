#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <stdlib.h>

// Mac Catalyst frameworks send +currentState to CATransaction; it is private.
@interface CATransaction (CatalystPrivate)
+ (id)currentState;
@end

static int failures;

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        failures++;
    }
}

int main(void)
{
    @autoreleasepool
    {
        expect([CATransaction respondsToSelector:@selector(currentState)], @"CATransaction answers +currentState");
        expect([CATransaction currentState] == nil, @"no transaction is open at first");
        expect([CATransaction currentState] == nil, @"asking does not open a transaction");

        [CATransaction begin];
        id outer = [CATransaction currentState];
        expect(outer != nil, @"an open transaction has a state");
        expect([CATransaction currentState] == outer, @"the state is stable while the transaction is open");

        [CATransaction begin];
        id inner = [CATransaction currentState];
        expect(inner != nil && inner != outer, @"a nested transaction has its own state");
        [CATransaction commit];
        expect([CATransaction currentState] == outer, @"the outer state returns after the nested commit");
        [CATransaction commit];
        expect([CATransaction currentState] == nil, @"no state once every transaction is committed");

        if (failures == 0)
            NSLog(@"PASS: CATransaction +currentState");
    }
    return failures == 0 ? 0 : 1;
}
