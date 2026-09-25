#import <AppKit/AppKit.h>
#include <stdio.h>

@interface NSPopUpButton (BindingProbe)
- (void) _setContent: (id) values;
- (void) _setContentValues: (id) values;
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSPopUpButton *popup = [[NSPopUpButton alloc]
                initWithFrame: NSMakeRect(0, 0, 140, 24) pullsDown: NO];
        [popup _setContentValues: @[ @"UTF-8", @"UTF-16" ]];
        BOOL passed = [popup numberOfItems] == 2;
        [popup _setContentValues: @""];
        passed &= [popup numberOfItems] == 0;
        [popup _setContent: @""];
        passed &= [popup numberOfItems] == 0;
        [popup _setContentValues: @[ @"UTF-8" ]];
        passed &= [popup numberOfItems] == 1;
        [popup release];
        printf("popup binding placeholders: %s\n", passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
