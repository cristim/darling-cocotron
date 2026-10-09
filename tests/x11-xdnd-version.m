#import <AppKit/AppKit.h>
#include <stdio.h>
#include <stdlib.h>

// Guest half of the XDND version-byte regression; x11-xdnd-version-helper.c is the source.
// See x11-xdnd-version.md for the commands.
static int entered;
static NSDragOperation sourceMask;

@interface VersionView : NSView
@end
@implementation VersionView
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    ++entered;
    sourceMask = [sender draggingSourceOperationMask];
    return NSDragOperationMove | NSDragOperationCopy;
}
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
    return NSDragOperationMove | NSDragOperationCopy;
}
@end

int main(void) {
    @autoreleasepool {
        setbuf(stdout, NULL);
        [NSApplication sharedApplication];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 300, 200)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        [window setTitle:@"xdnd-target"];
        VersionView *view = [[[VersionView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)] autorelease];
        [view registerForDraggedTypes:@[NSFilenamesPboardType]];
        [window setContentView:view];
        [window makeKeyAndOrderFront:nil];

        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
        BOOL ready = NO;
        for (;;) {
            if (!ready && [deadline timeIntervalSinceNow] <= 0) {
                printf("READY\n");
                ready = YES;
                deadline = [NSDate dateWithTimeIntervalSinceNow:30];
            }
            if (ready && (entered > 0 || [deadline timeIntervalSinceNow] <= 0))
                break;
            NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                                untilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if (event != nil)
                [NSApp sendEvent:event];
        }

        if (entered < 1) {
            NSLog(@"FAIL: draggingEntered: never ran");
            return 1;
        }
        // A source that advertises only move, speaking version 5, must yield exactly move.
        // Reading the version as 0 would yield copy.
        if (sourceMask != NSDragOperationMove) {
            NSLog(@"FAIL: draggingSourceOperationMask was 0x%lx, expected move (0x%lx)",
                  (unsigned long)sourceMask, (unsigned long)NSDragOperationMove);
            return 1;
        }
        NSLog(@"PASS: x11-xdnd-version");
    }
    return 0;
}
