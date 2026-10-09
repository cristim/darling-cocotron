#import <AppKit/AppKit.h>
#include <stdio.h>
#include <stdlib.h>

// Guest half of the Control-mapping regression; x11-modifier-defaults-helper.c injects
// the keys. See x11-modifier-defaults.md for the commands.
static void expect(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        setbuf(stdout, NULL);
        // Documented per-user mapping: the key AppKit reports as Control is treated as Command.
        [[NSUserDefaults standardUserDefaults]
                setObject:@{@"LeftControl" : @"Command"} forKey:@"NSModifierFlagMapping"];
        [NSApplication sharedApplication];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(50, 50, 300, 150)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        [window setTitle:@"mod-probe"];
        [window makeKeyAndOrderFront:nil];
        NSDate *settle = [NSDate dateWithTimeIntervalSinceNow:2];
        while ([settle timeIntervalSinceNow] > 0) {
            NSEvent *e = [NSApp nextEventMatchingMask:NSAnyEventMask
                                            untilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]
                                               inMode:NSDefaultRunLoopMode
                                              dequeue:YES];
            if (e != nil)
                [NSApp sendEvent:e];
        }
        printf("READY\n");

        // X state sent by the helper, in order, and the flags each must produce.
        const NSUInteger mask = NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask;
        const NSUInteger expected[] = {
            NSCommandKeyMask,                  // ControlMask
            NSCommandKeyMask | NSShiftKeyMask, // ControlMask | ShiftMask
            NSCommandKeyMask,                  // Mod4Mask (unaffected by the mapping)
            NSShiftKeyMask,                    // ShiftMask (unaffected by the mapping)
        };
        unsigned received = 0;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30];
        while (received < 4 && [deadline timeIntervalSinceNow] > 0) {
            NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                                untilDate:deadline
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if (event == nil)
                break;
            if ([event type] != NSKeyDown) {
                [NSApp sendEvent:event];
                continue;
            }
            NSUInteger flags = [event modifierFlags] & mask;
            printf("KEY %u flags=0x%lx\n", received, (unsigned long)flags);
            expect(flags == expected[received],
                   [NSString stringWithFormat:@"key %u had flags 0x%lx, expected 0x%lx",
                                              received, (unsigned long)flags,
                                              (unsigned long)expected[received]]);
            ++received;
        }
        expect(received == 4, @"fewer than 4 key events arrived");
        NSLog(@"PASS: x11-modifier-defaults");
    }
    return 0;
}
