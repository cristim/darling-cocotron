#import <AppKit/AppKit.h>
#include <stdlib.h>

// Private NSApplication methods that Mac Catalyst frameworks require.
static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface NSApplication (CatalystPrivate)
- (NSWindow *)_findWindowUsingContextID:(uint32_t)contextID;
- (BOOL)_restoreMiniaturizedWindow;
@end

int main(void)
{
    @autoreleasepool
    {
        NSApplication *app = [NSApplication sharedApplication];

        expect([app respondsToSelector:@selector(_findWindowUsingContextID:)],
               @"NSApplication answers -_findWindowUsingContextID:");
        expect([app _findWindowUsingContextID:0x7ffffff0] == nil, @"an unknown context id finds no window");

        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES];
        expect([app _findWindowUsingContextID:(uint32_t)[window windowNumber]] == window,
               @"the context id of a window is its window number");
        [window release];

        expect([app respondsToSelector:@selector(_restoreMiniaturizedWindow)],
               @"NSApplication answers -_restoreMiniaturizedWindow");
        expect(![app _restoreMiniaturizedWindow], @"with no miniaturized window nothing is restored");

        NSLog(@"PASS: NSApplication catalyst methods");
    }
    return 0;
}
