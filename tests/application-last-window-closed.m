// AppKit regression: closing the last window terminates only when the delegate asks for it.
// Needs a display connection (any AppKit backend).
#import <AppKit/AppKit.h>
#include <stdio.h>

static BOOL terminateRequested;

@interface Recorder : NSObject
@end
@implementation Recorder
- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) sender {
    terminateRequested = YES;
    return NSTerminateCancel;
}
@end

@interface Answering : Recorder
@property BOOL answer;
@end
@implementation Answering
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) sender {
    return self.answer;
}
@end

@interface Driver : NSObject
@end
@implementation Driver {
    NSArray *_cases;
    NSUInteger _step;
    int _failures;
}

- (instancetype) init {
    Answering *yes = [Answering new], *no = [Answering new];
    yes.answer = YES;
    // label, delegate, whether a window is closed, expected termination request
    _cases = [@[
        @[@"event with no window ever shown", yes, @NO, @NO],
        @[@"delegate without the method", [Recorder new], @YES, @NO],
        @[@"delegate answers NO", no, @YES, @NO],
        @[@"delegate answers YES", yes, @YES, @YES],
    ] retain];
    return self;
}

- (void) postDummyEvent {
    [NSApp postEvent: [NSEvent otherEventWithType: NSApplicationDefined location: NSZeroPoint
                                    modifierFlags: 0 timestamp: 0 windowNumber: 0 context: nil
                                          subtype: 0 data1: 0 data2: 0]
             atStart: NO];
}

- (void) tick: (NSTimer *) timer {
    NSUInteger index = _step / 2;
    if (index >= [_cases count]) {
        printf("last window checks=%lu failures=%d\n", (unsigned long)[_cases count], _failures);
        exit(_failures != 0);
    }
    NSArray *c = _cases[index];
    if (_step % 2 == 0) {
        terminateRequested = NO;
        [NSApp setDelegate: c[1]];
        if ([c[2] boolValue]) {
            NSWindow *window = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 200, 100)
                                                           styleMask: NSTitledWindowMask
                                                             backing: NSBackingStoreBuffered
                                                               defer: NO];
            [window setReleasedWhenClosed: NO];
            [window makeKeyAndOrderFront: nil];
            [window close];
            [window release];
        }
        [self postDummyEvent];
    } else {
        BOOL ok = terminateRequested == [c[3] boolValue];
        printf("%s %s: termination %srequested\n", ok ? "PASS" : "FAIL", [c[0] UTF8String],
               terminateRequested ? "" : "not ");
        _failures += !ok;
    }
    _step++;
}
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        Driver *driver = [Driver new];
        [NSTimer scheduledTimerWithTimeInterval: 0.2 target: driver selector: @selector(tick:)
                                       userInfo: nil repeats: YES];
        [NSApp run];
    }
    return 2;
}
