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
        BOOL passed = [window titleVisibility] == NSWindowTitleVisible;
        [window setTitleVisibility: NSWindowTitleHidden];
        passed &= [window titleVisibility] == NSWindowTitleHidden;
        [window setTitleVisibility: NSWindowTitleVisible];
        passed &= [window titleVisibility] == NSWindowTitleVisible;
        [window release];

        NSWindowTemplate *windowTemplate = [NSWindowTemplate new];
        [windowTemplate setClassName: @"NSWindow"];
        [windowTemplate setStyleMask: NSWindowStyleMaskTitled];
        [windowTemplate setTitleVisibility: NSWindowTitleHidden];
        NSWindow *decoded = [windowTemplate awakeAfterUsingCoder: nil];
        passed &= [decoded titleVisibility] == NSWindowTitleHidden;
        [decoded release];

        printf("window title visibility: %s\n", passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
