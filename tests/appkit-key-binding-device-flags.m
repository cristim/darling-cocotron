#import <AppKit/AppKit.h>
#import "../AppKit/NSKeyboardBinding/NSKeyboardBinding.h"
#import "../AppKit/NSKeyboardBinding/NSKeyboardBindingManager.h"
#include <stdio.h>

// Wayland sends physical left/right Shift bits as well as the aggregate bit.
// Key bindings must still select the same command as the aggregate bit alone.
// Before device bits are masked, the second lookup fails (0x20002 != 0x20000)
// and keyDown: inserts a space for the unbound function key.
int main(void)
{
    @autoreleasepool {
        NSDictionary *bindings = @{@"shift,keypad,0xF703" : @"moveForwardAndModifySelection:"};
        NSKeyboardBindingManager *manager = [[NSKeyboardBindingManager alloc] initWithDictionary:bindings];
        NSUInteger flags[] = {NSShiftKeyMask, NSShiftKeyMask | 2,
                              NSShiftKeyMask | 4, NSShiftKeyMask | 6};
        for (NSUInteger i = 0; i < sizeof(flags) / sizeof(flags[0]); ++i) {
            NSKeyboardBinding *binding = [manager keyBindingWithString:@"\uF703"
                                                          modifierFlags:flags[i]];
            if (![[binding selectorNames] isEqual:@[@"moveForwardAndModifySelection:"]]) {
                fprintf(stderr, "FAIL: Shift+Right binding with flags 0x%lx\n",
                        (unsigned long)flags[i]);
                return 1;
            }
        }
        NSKeyboardBindingManager *defaults = [NSKeyboardBindingManager defaultKeyBindingManager];
        struct { unichar key; NSUInteger flags; const char *command; } shortcuts[] = {
            {0xF702, NSControlKeyMask, "moveWordBackward:"},
            {0xF703, NSControlKeyMask, "moveWordForward:"},
            {0xF702, NSControlKeyMask | NSShiftKeyMask, "moveWordBackwardAndModifySelection:"},
            {0xF703, NSControlKeyMask | NSShiftKeyMask, "moveWordForwardAndModifySelection:"},
            {'z', NSControlKeyMask, "undo:"},
            {'Z', NSControlKeyMask | NSShiftKeyMask, "redo:"},
            {'y', NSControlKeyMask, "redo:"},
            {'z', NSControlKeyMask | NSShiftKeyMask, "redo:"},
            {0xF700, NSControlKeyMask, "moveToBeginningOfParagraph:"},
            {0xF701, NSControlKeyMask, "moveToEndOfParagraph:"},
            {0xF700, NSControlKeyMask | NSShiftKeyMask, "moveParagraphBackwardAndModifySelection:"},
            {0xF701, NSControlKeyMask | NSShiftKeyMask, "moveParagraphForwardAndModifySelection:"},
        };
        for (NSUInteger i = 0; i < sizeof(shortcuts) / sizeof(shortcuts[0]); ++i) {
            NSString *key = [NSString stringWithCharacters:&shortcuts[i].key length:1];
            for (NSUInteger device = 0; device <= 3; ++device) {
                NSArray *commands = [[defaults keyBindingWithString:key
                    modifierFlags:shortcuts[i].flags | device] selectorNames];
                if (![commands isEqual:@[[NSString stringWithUTF8String:shortcuts[i].command]]]) {
                    fprintf(stderr, "FAIL: shortcut U+%04x flags=0x%lx expected %s\n",
                            shortcuts[i].key, (unsigned long)(shortcuts[i].flags | device),
                            shortcuts[i].command);
                    return 1;
                }
            }
        }
        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 300, 100)];
        [view setString:@"abc"];
        [view setSelectedRange:NSMakeRange(1, 0)];
        NSEvent *arrow = [NSEvent keyEventWithType:NSKeyDown
                                          location:NSZeroPoint
                                     modifierFlags:NSShiftKeyMask | 2
                                         timestamp:0
                                      windowNumber:0
                                           context:nil
                                        characters:@"\uF703"
                       charactersIgnoringModifiers:@"\uF703"
                                         isARepeat:NO
                                           keyCode:124];
        [view keyDown:arrow];
        if (!NSEqualRanges([view selectedRange], NSMakeRange(1, 1)) ||
            ![[view string] isEqual:@"abc"]) {
            fprintf(stderr, "FAIL: Wayland Shift+Right edited text or missed selection\n");
            return 1;
        }
        [view setSelectedRange:NSMakeRange(2, 0)];
        NSEvent *left = [NSEvent keyEventWithType:NSKeyDown
                                         location:NSZeroPoint
                                    modifierFlags:NSShiftKeyMask | 4
                                        timestamp:0
                                     windowNumber:0
                                          context:nil
                                       characters:@"\uF702"
                      charactersIgnoringModifiers:@"\uF702"
                                        isARepeat:NO
                                          keyCode:123];
        [view keyDown:left];
        if (!NSEqualRanges([view selectedRange], NSMakeRange(1, 1)) ||
            ![[view string] isEqual:@"abc"]) {
            NSRange actual = [view selectedRange];
            fprintf(stderr, "FAIL: Wayland Shift+Left range=%lu,%lu text=%s\n",
                    (unsigned long)actual.location, (unsigned long)actual.length,
                    [[view string] UTF8String]);
            return 1;
        }
        [view setSelectedRange:NSMakeRange(2, 0)];
        [view moveToBeginningOfDocumentAndModifySelection:nil];
        [view moveToEndOfDocumentAndModifySelection:nil];
        if (!NSEqualRanges([view selectedRange], NSMakeRange(2, 1))) {
            fprintf(stderr, "FAIL: document selection reversal lost its anchor\n");
            return 1;
        }
        [view moveToBeginningOfDocumentAndModifySelection:nil];
        if (!NSEqualRanges([view selectedRange], NSMakeRange(0, 2))) {
            fprintf(stderr, "FAIL: reverse document selection lost its anchor\n");
            return 1;
        }
        [view setSelectedRange:NSMakeRange(2, 0)];
        [view keyDown:left];
        NSEvent *copy = [NSEvent keyEventWithType:NSKeyDown
                                         location:NSZeroPoint
                                    modifierFlags:NSCommandKeyMask | 8
                                        timestamp:0 windowNumber:0 context:nil
                                       characters:@"c" charactersIgnoringModifiers:@"c"
                                        isARepeat:NO keyCode:8];
        [view keyDown:copy];
        if (![[[NSPasteboard generalPasteboard] stringForType:NSStringPboardType] isEqual:@"b"]) {
            fprintf(stderr, "FAIL: Command+C did not copy the selection\n");
            return 1;
        }
        [view setSelectedRange:NSMakeRange(3, 0)];
        NSEvent *paste = [NSEvent keyEventWithType:NSKeyDown
                                          location:NSZeroPoint
                                     modifierFlags:NSCommandKeyMask | 8
                                         timestamp:0 windowNumber:0 context:nil
                                        characters:@"v" charactersIgnoringModifiers:@"v"
                                         isARepeat:NO keyCode:9];
        [view keyDown:paste];
        if (![[view string] isEqual:@"abcb"]) {
            fprintf(stderr, "FAIL: Command+V result=%s\n", [[view string] UTF8String]);
            return 1;
        }
        puts("PASS: Shift+Arrows select, Command+C copies, Command+V pastes");
    }
    return 0;
}
