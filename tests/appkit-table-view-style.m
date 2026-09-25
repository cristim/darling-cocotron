#import <AppKit/AppKit.h>
#include <stdio.h>

@interface StyleObserver : NSObject {
@public
    NSInteger notifications;
}
@end

@implementation StyleObserver
- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object
                        change: (NSDictionary *) change context: (void *) context {
    if ([keyPath isEqualToString: @"style"]) notifications++;
}
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSTableView *table = [[NSTableView alloc] initWithFrame: NSMakeRect(0, 0, 200, 120)];
        BOOL passed = [table style] == NSTableViewStyleAutomatic
                   && [table effectiveStyle] == NSTableViewStyleInset;
        StyleObserver *observer = [StyleObserver new];
        [table addObserver: observer forKeyPath: @"style" options: 0 context: NULL];
        [table setStyle: NSTableViewStylePlain];
        passed &= [table style] == NSTableViewStylePlain
               && [table effectiveStyle] == NSTableViewStylePlain
               && observer->notifications == 1;
        [table setStyle: NSTableViewStyleAutomatic];
        [table setSelectionHighlightStyle: NSTableViewSelectionHighlightStyleSourceList];
        passed &= [table effectiveStyle] == NSTableViewStyleSourceList;
        [table setSelectionHighlightStyle: NSTableViewSelectionHighlightStyleRegular];
        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 220, 140)];
        [scroll setBorderType: NSBezelBorder];
        [scroll setDocumentView: table];
        passed &= [table effectiveStyle] == NSTableViewStyleFullWidth;
        [table removeObserver: observer forKeyPath: @"style"];
        [observer release];
        [scroll release];
        [table release];
        printf("table view style: %s\n", passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
