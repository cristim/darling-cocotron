// Standalone AppKit regression. No display connection or application init needed.
#import <AppKit/AppKit.h>
#include <stdio.h>
#include <stdlib.h>

@interface NSApplication (TerminateCheck)
- (void) _checkForTerminate;
@end

@interface NSWindow (TerminateCheckAccess)
- (BOOL) _isHiddenForDeactivate;
@end

@interface FakeWindow : NSWindow {
    BOOL _fakeVisible, _fakeHidden;
}
- (void) setFakeVisible: (BOOL) visible hidden: (BOOL) hidden;
@end

@implementation FakeWindow
- (void) setFakeVisible: (BOOL) visible hidden: (BOOL) hidden {
    _fakeVisible = visible;
    _fakeHidden = hidden;
}
- (BOOL) isVisible { return _fakeVisible; }
- (BOOL) _isHiddenForDeactivate { return _fakeHidden; }
@end

@interface SpyApp : NSApplication {
@public
    int terminateCount;
}
- (void) useDelegate: (id) delegate;
- (void) setWindows: (NSArray *) windows;
@end

@implementation SpyApp
- (void) useDelegate: (id) delegate { _delegate = delegate; }
- (void) setWindows: (NSArray *) windows { _windows = [windows mutableCopy]; }
- (void) terminate: (id) sender { terminateCount++; }
@end

@interface QuitDelegate : NSObject
@end
@implementation QuitDelegate
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) app { return YES; }
@end

@interface StayDelegate : NSObject
@end
@implementation StayDelegate
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) app { return NO; }
@end

@interface SilentDelegate : NSObject
@end
@implementation SilentDelegate
@end

static int failures, checks;

static void expect(const char *step, SpyApp *app, id delegate, NSArray *windows, int expected) {
    app->terminateCount = 0;
    [app useDelegate: delegate];
    [app setWindows: windows];
    [app _checkForTerminate];
    checks++;
    if (app->terminateCount != expected) {
        printf("FAIL %s: terminate calls=%d expected %d\n", step, app->terminateCount, expected);
        failures++;
    }
}

int main(void) {
    @autoreleasepool {
        if (getenv("DARLING_QUIT_ON_LAST_WINDOW") != NULL ||
            [[NSUserDefaults standardUserDefaults] objectForKey: @"NSQuitOnLastWindowClosed"] != nil) {
            puts("FAIL: unset DARLING_QUIT_ON_LAST_WINDOW and NSQuitOnLastWindowClosed first");
            return 1;
        }

        SpyApp *app = [SpyApp alloc];
        if (![app respondsToSelector: @selector(_checkForTerminate)]) {
            puts("FAIL: missing _checkForTerminate");
            return 1;
        }

        FakeWindow *visible = [FakeWindow alloc];
        [visible setFakeVisible: YES hidden: NO];
        FakeWindow *deactivated = [FakeWindow alloc];
        [deactivated setFakeVisible: NO hidden: YES];
        FakeWindow *closed = [FakeWindow alloc];
        [closed setFakeVisible: NO hidden: NO];

        id yes = [[QuitDelegate new] autorelease];
        id no = [[StayDelegate new] autorelease];
        id silent = [[SilentDelegate new] autorelease];
        NSArray *none = [NSArray array];
        NSArray *onlyClosed = [NSArray arrayWithObject: closed];

        expect("delegate YES, no windows", app, yes, none, 1);
        expect("delegate YES, closed window", app, yes, onlyClosed, 1);
        expect("delegate NO, no windows", app, no, none, 0);
        expect("delegate NO, closed window", app, no, onlyClosed, 0);
        expect("no delegate method, closed window", app, silent, onlyClosed, 0);
        expect("nil delegate, closed window", app, nil, onlyClosed, 0);
        expect("delegate YES, visible window", app, yes, [NSArray arrayWithObject: visible], 0);
        expect("delegate YES, window hidden for deactivation", app, yes,
               [NSArray arrayWithObject: deactivated], 0);
        expect("delegate YES, closed and visible", app, yes,
               [NSArray arrayWithObjects: closed, visible, nil], 0);

        printf("terminate after last window checks=%d failures=%d\n", checks, failures);
        return failures != 0;
    }
}
