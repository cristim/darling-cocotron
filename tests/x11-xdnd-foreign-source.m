#import <AppKit/AppKit.h>
#include <stdio.h>
#include <stdlib.h>

// Guest half of the standard-protocol XDND drop test; x11-xdnd-foreign-source-helper.c is the
// source. See x11-xdnd-foreign-source.md for the commands.
static int performed;
static NSArray *dropped;

@interface ForeignView : NSView
@end
@implementation ForeignView
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}
// Cocotron's NSView default answers NO, which would skip performDragOperation:.
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
    return YES;
}
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    dropped = [[[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType] retain];
    ++performed;
    return dropped != nil;
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
        ForeignView *view = [[[ForeignView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)] autorelease];
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
            if (ready && (performed > 0 || [deadline timeIntervalSinceNow] <= 0))
                break;
            NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                                untilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if (event != nil)
                [NSApp sendEvent:event];
        }

        if (performed < 1) {
            NSLog(@"FAIL: performDragOperation: never ran, the drop was refused");
            return 1;
        }
        NSArray *expected = @[@"/Volumes/SystemRoot/xdnd-probe/a b.txt", @"/Volumes/SystemRoot/xdnd-probe/two.txt"];
        if (![dropped isEqual:expected]) {
            NSLog(@"FAIL: NSFilenamesPboardType was %@, expected %@", dropped, expected);
            return 1;
        }
        NSLog(@"PASS: x11-xdnd-foreign-source");
    }
    return 0;
}
