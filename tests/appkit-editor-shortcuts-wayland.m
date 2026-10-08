#import <AppKit/AppKit.h>
#include <stdio.h>

// Drive this window with a Wayland virtual keyboard or X11 XTest. The printed
// ranges and clipboard contents expose the backend -> AppKit -> editor path.
@interface ShortcutProbe : NSObject
@property (retain) NSTextView *editor;
@property (copy) NSString *lastState;
- (void)sample:(NSTimer *)timer;
@end

@implementation ShortcutProbe
- (void)sample:(NSTimer *)timer
{
    NSRange range = [_editor selectedRange];
    NSString *copy = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType];
    NSString *state = [NSString stringWithFormat:@"range=%lu,%lu text=%@ clipboard=%@",
                       (unsigned long)range.location, (unsigned long)range.length,
                       [[_editor string] stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"], copy ? [copy stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"] : @"<nil>"];
    if (![state isEqual:_lastState]) {
        self.lastState = state;
        printf("STATE %s\n", [state UTF8String]);
        fflush(stdout);
    }
}
- (void)dealloc
{
    [_editor release];
    [_lastState release];
    [super dealloc];
}
@end

@interface LoggingTextView : NSTextView
@end
@implementation LoggingTextView
- (void)doCommandBySelector:(SEL)selector
{
    printf("COMMAND %s\n", [NSStringFromSelector(selector) UTF8String]);
    fflush(stdout);
    [super doCommandBySelector:selector];
}
- (void)paste:(id)sender
{
    NSPasteboard *board = [NSPasteboard generalPasteboard];
    printf("PASTE rich=%d rtf=%lu plain=%s\n", [self isRichText],
           (unsigned long)[[board dataForType:NSRTFPboardType] length],
           [[board stringForType:NSStringPboardType] UTF8String]);
    fflush(stdout);
    [super paste:sender];
    printf("PASTE result=%s\n", [[self string] UTF8String]);
    fflush(stdout);
}
- (void)keyDown:(NSEvent *)event
{
    printf("KEY flags=0x%lx characters=%s\n", (unsigned long)[event modifierFlags],
           [[event characters] UTF8String]);
    fflush(stdout);
    [super keyDown:event];
}
@end

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(50, 50, 500, 200)
                                                     styleMask:NSTitledWindowMask
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
        [window setTitle:@"Caret Shift Clipboard Probe"];
        NSTextView *editor = [[LoggingTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 200)];
        [editor setAllowsUndo:YES];
        [editor setString:@"abc"];
        [editor setSelectedRange:NSMakeRange(1, 0)];
        [window setContentView:editor];
        [window makeKeyAndOrderFront:nil];
        BOOL focused = [window makeFirstResponder:editor];
        printf("FOCUS accepted=%d responder=%s editable=%d\n", focused,
               [NSStringFromClass([[window firstResponder] class]) UTF8String],
               [editor isEditable]);
        fflush(stdout);
        ShortcutProbe *probe = [ShortcutProbe new];
        probe.editor = editor;
        [probe sample:nil];
        [NSTimer scheduledTimerWithTimeInterval:0.25 target:probe
                                       selector:@selector(sample:) userInfo:nil repeats:YES];
        [NSApp run];
    }
    return 0;
}
