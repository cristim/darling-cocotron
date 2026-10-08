#import <AppKit/AppKit.h>
#import "../AppKit/NSMenu.subproj/NSMenuView.h"
#import "../AppKit/NSMenu.subproj/NSMenuWindow.h"
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSTextView *editor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 300, 100)];
        [editor setString:@"abc"];
        [editor setSelectedRange:NSMakeRange(0, 3)];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 100)
            styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
        [window setContentView:editor];
        [window makeFirstResponder:editor];
        NSEvent *click = [NSEvent mouseEventWithType:NSRightMouseDown
            location:NSMakePoint(8, 90) modifierFlags:0 timestamp:1 windowNumber:[window windowNumber]
            context:nil eventNumber:0 clickCount:1 pressure:1];
        // Use a deliberately enabled menu item to distinguish cancellation from validation.
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Context"];
        [menu setAutoenablesItems:NO];
        [menu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@""];
        NSMenuWindow *popup = [[NSMenuWindow alloc] initWithMenu:menu];
        [popup setReleasedWhenClosed:NO];
        NSMenuView *view = [popup menuView];
        NSEvent *start = [NSEvent mouseEventWithType:NSRightMouseDown
            location:NSMakePoint(10, NSHeight([view bounds]) - 10) modifierFlags:0 timestamp:1
            windowNumber:[popup windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1];
        NSEvent *escape = [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:0
            timestamp:2 windowNumber:[popup windowNumber] context:nil characters:@"\033"
            charactersIgnoringModifiers:@"\033" isARepeat:NO keyCode:53];
        [NSApp postEvent:escape atStart:YES];
        if ([view trackForEvent:start] != nil) {
            fprintf(stderr, "FAIL: cancelling the highlighted context action returned Cut\n");
            return 1;
        }
        NSEvent *deactivate = [NSEvent otherEventWithType:NSAppKitDefined location:NSZeroPoint
            modifierFlags:0 timestamp:2 windowNumber:[popup windowNumber] context:nil
            subtype:NSApplicationDeactivated data1:0 data2:0];
        [NSApp postEvent:deactivate atStart:YES];
        if ([view trackForEvent:start] != nil) {
            fprintf(stderr, "FAIL: deactivating a context menu returned its highlighted action\n");
            return 1;
        }
        NSMenu *context = [editor menuForEvent:click];
        if ([[context itemAtIndex:0] isSeparatorItem]) {
            fprintf(stderr, "FAIL: context menu starts with a separator\n");
            return 1;
        }
        [editor setString:@""];
        [editor setSelectedRange:NSMakeRange(0, 0)];
        context = [editor menuForEvent:click];
        for (NSMenuItem *item in [context itemArray]) {
            if ([[item title] isEqual:@"No Guesses Found"]) {
                fprintf(stderr, "FAIL: empty editor offers spelling guesses\n");
                return 1;
            }
        }
        for (NSMenuItem *item in [context itemArray]) {
            if (([item action] == @selector(cut:) || [item action] == @selector(copy:)) &&
                [editor validateMenuItem:item]) {
                fprintf(stderr, "FAIL: empty selection enables Cut or Copy\n");
                return 1;
            }
        }
        [editor setString:@"abc"];
        [editor setSelectedRange:NSMakeRange(0, 3)];
        [editor setEditable:NO];
        NSMenuItem *cut = [[NSMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@""];
        NSMenuItem *paste = [[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@""];
        if ([editor validateMenuItem:cut] || [editor validateMenuItem:paste]) {
            fprintf(stderr, "FAIL: read-only editor enables Cut or Paste\n");
            return 1;
        }
        puts("PASS: cancelled context actions return nil; selected/empty menus have no bogus spelling section");
    }
    return 0;
}
