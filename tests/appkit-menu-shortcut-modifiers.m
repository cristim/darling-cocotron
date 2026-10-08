#import <AppKit/AppKit.h>
#include <stdio.h>

@interface ShortcutTarget : NSObject
@property NSUInteger undoCount;
@property NSUInteger redoCount;
- (void)undo:(id)sender;
- (void)redo:(id)sender;
@end
@implementation ShortcutTarget
- (void)undo:(id)sender { _undoCount++; }
- (void)redo:(id)sender { _redoCount++; }
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        ShortcutTarget *target = [ShortcutTarget new];
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Edit"];
        [menu setAutoenablesItems:NO];
        NSMenuItem *undo = [menu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
        NSMenuItem *redo = [menu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];
        [undo setTarget:target];
        [redo setTarget:target];
        [redo setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask];
        for (NSString *key in @[@"z", @"Z"]) {
            NSEvent *event = [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint
                modifierFlags:NSCommandKeyMask | NSShiftKeyMask | 10 timestamp:0
                windowNumber:0 context:nil characters:key charactersIgnoringModifiers:key
                isARepeat:NO keyCode:6];
            if (![menu performKeyEquivalent:event] || target.undoCount != 0) {
                fprintf(stderr, "FAIL: Command+Shift+%s dispatched Undo or missed Redo\n", [key UTF8String]);
                return 1;
            }
        }
        if (target.redoCount != 2) return 1;
        // An uppercase key equivalent also implies Shift in older nibs.
        [redo setKeyEquivalent:@"Z"];
        [redo setKeyEquivalentModifierMask:NSCommandKeyMask];
        NSEvent *event = [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint
            modifierFlags:NSCommandKeyMask | NSShiftKeyMask timestamp:0 windowNumber:0
            context:nil characters:@"Z" charactersIgnoringModifiers:@"Z" isARepeat:NO keyCode:6];
        if (![menu performKeyEquivalent:event] || target.redoCount != 3 || target.undoCount != 0) return 1;
        puts("PASS: Command+Shift+Z dispatches Redo with both backend character forms");
    }
    return 0;
}
