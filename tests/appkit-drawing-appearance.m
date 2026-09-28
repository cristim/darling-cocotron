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

@interface Probe : NSObject
@property(retain) NSAppearance *seen;
@property BOOL done;
@end

@implementation Probe
- (void)look { self.seen = [NSAppearance currentDrawingAppearance]; self.done = YES; }
@end

int main(void)
{
    @autoreleasepool
    {
        NSAppearance *aqua = [NSAppearance currentDrawingAppearance];
        expect([aqua.name isEqual:NSAppearanceNameAqua], @"the default drawing appearance is Aqua");
        NSAppearance *dark = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        NSAppearance *light = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        NSView *view = [[NSView alloc] initWithFrame:NSZeroRect];
        __block BOOL ran = NO;
        [dark performAsCurrentDrawingAppearance:^{
            expect([NSAppearance currentDrawingAppearance] == dark && [NSAppearance currentAppearance] == dark &&
                       view.effectiveAppearance == dark,
                   @"the block runs with the receiver as the drawing appearance");
            [light performAsCurrentDrawingAppearance:^{
                expect([NSAppearance currentDrawingAppearance] == light, @"nested blocks install their own");
            }];
            expect([NSAppearance currentDrawingAppearance] == dark, @"a nested block restores the outer appearance");

            Probe *probe = [Probe new];
            [NSThread detachNewThreadSelector:@selector(look) toTarget:probe withObject:nil];
            while (!probe.done)
                [NSThread sleepForTimeInterval:0.01];
            expect(probe.seen == aqua, @"other threads keep their own drawing appearance");
            ran = YES;
        }];
        expect(ran && [NSAppearance currentDrawingAppearance] == aqua, @"the appearance is restored after the block");

        @try {
            [dark performAsCurrentDrawingAppearance:^{
                [NSException raise:NSGenericException format:@"thrown inside the block"];
            }];
        } @catch (NSException *exception) {
        }
        expect([NSAppearance currentDrawingAppearance] == aqua, @"the appearance is restored when the block throws");
        NSLog(@"PASS: performAsCurrentDrawingAppearance scopes the drawing appearance to the block and thread");
    }
    return 0;
}
