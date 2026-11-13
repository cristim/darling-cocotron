// Undoing and redoing an attribute change in an NSTextView restores the attributes of every attribute run in the range,
// through NSTextStorage's public API only.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface UndoDelegate : NSObject <NSTextViewDelegate>
@property(retain) NSUndoManager *manager;
@end

@implementation UndoDelegate
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)view
{
    return self.manager;
}
@end

static NSColor *colorAt(NSTextStorage *storage, NSUInteger index)
{
    return [storage attribute:NSForegroundColorAttributeName atIndex:index effectiveRange:NULL];
}

int main(void)
{
    @autoreleasepool
    {
        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)];
        UndoDelegate *delegate = [[UndoDelegate alloc] init];
        delegate.manager = [[NSUndoManager alloc] init];
        [delegate.manager setGroupsByEvent:NO];
        [view setDelegate:delegate];
        [view setAllowsUndo:YES];

        NSTextStorage *storage = [view textStorage];
        [storage replaceCharactersInRange:NSMakeRange(0, 0) withString:@"red green blue"];
        NSColor *red = [NSColor redColor], *green = [NSColor greenColor], *blue = [NSColor blueColor];
        [storage addAttribute:NSForegroundColorAttributeName value:red range:NSMakeRange(0, 3)];
        [storage addAttribute:NSForegroundColorAttributeName value:green range:NSMakeRange(4, 5)];
        [storage addAttribute:NSForegroundColorAttributeName value:blue range:NSMakeRange(10, 4)];
        expect(colorAt(storage, 1) == red && colorAt(storage, 5) == green && colorAt(storage, 11) == blue, @"three runs set up");

        [delegate.manager beginUndoGrouping];
        [view setTextColor:[NSColor blackColor] range:NSMakeRange(0, 14)];
        [delegate.manager endUndoGrouping];
        expect([colorAt(storage, 1) isEqual:[NSColor blackColor]] && [colorAt(storage, 11) isEqual:[NSColor blackColor]], @"one colour over the whole range");
        expect([delegate.manager canUndo], @"the change registered an undo");

        [delegate.manager undo];
        expect(colorAt(storage, 1) == red, @"undo restores the first run");
        expect(colorAt(storage, 5) == green, @"undo restores the middle run");
        expect(colorAt(storage, 11) == blue, @"undo restores the last run");
        expect(colorAt(storage, 3) == nil, @"undo restores the run without a colour");

        [delegate.manager redo];
        expect([colorAt(storage, 1) isEqual:[NSColor blackColor]] && [colorAt(storage, 11) isEqual:[NSColor blackColor]], @"redo applies the colour again");
    }
    NSLog(@"appkit-text-undo-attributes: all checks passed");
    return 0;
}
