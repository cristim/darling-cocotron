#import <AppKit/AppKit.h>
#import "../AppKit/nib.subproj/NSWindowTemplate.h"
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSWindow *window = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 100, 100)
                                                      styleMask: NSWindowStyleMaskTitled
                                                        backing: NSBackingStoreBuffered
                                                          defer: NO];
        NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                              NSWindowCollectionBehaviorIgnoresCycle;
        [window setCollectionBehavior: behavior];
        BOOL passed = [window collectionBehavior] == behavior;
        [window setCollectionBehavior: NSWindowCollectionBehaviorDefault];
        passed &= [window collectionBehavior] == NSWindowCollectionBehaviorDefault;
        [window release];

        NSWindowTemplate *windowTemplate = [NSWindowTemplate new];
        [windowTemplate setClassName: @"NSWindow"];
        [windowTemplate setStyleMask: NSWindowStyleMaskTitled];
        [windowTemplate setCollectionBehavior: behavior];
        NSWindow *decoded = [windowTemplate awakeAfterUsingCoder: nil];
        passed &= [decoded collectionBehavior] == behavior;
        [decoded release];
        printf("window collection behavior: %s\n", passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
