#include <AppKit/NSTextInput.h>
#include <AppKit/NSTextInput_Internal.h>
#import <AppKit/NSEvent.h>

@interface NSObject (TextInputClientDelivery)
- (void)insertText:(id)text replacementRange:(NSRange)range;
- (void)insertText:(id)text;
- (void)doCommandBySelector:(SEL)selector;
- (void)unmarkText;
@end

NSString *const NSTextInputContextKeyboardSelectionDidChangeNotification = @"NSTextInputContextKeyboardSelectionDidChangeNotification";

NSString *const NSTextInputReplacementRangeAttributeName = @"NSTextInputReplacementRangeAttributeName";

@implementation NSTextInputContext
- (instancetype)initWithClient:(id)client {
    if ((self = [super init])) _client = client;
    return self;
}
- (id)client { return _client; }
- (void)activate {}
- (void)deactivate {}
- (void)invalidateCharacterCoordinates {}
- (void)discardMarkedText {
    if ([_client respondsToSelector:@selector(unmarkText)]) [_client unmarkText];
}
- (BOOL)handleEvent:(NSEvent *)event {
    if ([event type] != NSKeyDown || ([event modifierFlags] & NSCommandKeyMask)) return NO;
    NSString *text = [event characters];
    if (![text length]) return NO;
    unichar character = [text characterAtIndex:0];
    SEL command = NULL;
    switch (character) {
    case 0x7f: case 0x08: command = @selector(deleteBackward:); break;
    case '\r': case '\n': command = @selector(insertNewline:); break;
    case '\t': command = @selector(insertTab:); break;
    case 0x1b: command = @selector(cancelOperation:); break;
    case NSLeftArrowFunctionKey: command = @selector(moveLeft:); break;
    case NSRightArrowFunctionKey: command = @selector(moveRight:); break;
    case NSUpArrowFunctionKey: command = @selector(moveUp:); break;
    case NSDownArrowFunctionKey: command = @selector(moveDown:); break;
    case NSDeleteFunctionKey: command = @selector(deleteForward:); break;
    }
    if (command) {
        if (![_client respondsToSelector:@selector(doCommandBySelector:)]) return NO;
        [_client doCommandBySelector:command];
    } else {
        if (character < 0x20 || (character >= 0xf700 && character <= 0xf8ff) ||
            ([event modifierFlags] & NSControlKeyMask)) return NO;
        if ([_client respondsToSelector:@selector(insertText:replacementRange:)])
            [_client insertText:text replacementRange:NSMakeRange(NSNotFound, 0)];
        else if ([_client respondsToSelector:@selector(insertText:)]) [_client insertText:text];
        else return NO;
    }
    return YES;
}

@end
