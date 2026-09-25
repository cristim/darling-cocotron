#import <AppKit/AppKit.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        NSBundle *bundle = [NSBundle bundleWithPath: @"/usr/local/share/ImageProbe.bundle"];
        NSURL *named = [bundle URLForImageResource: @"probe"];
        NSURL *withExtension = [bundle URLForImageResource: @"probe.png"];
        BOOL passed = [named isFileURL]
                   && [[named path] hasSuffix: @"/Contents/Resources/probe.png"]
                   && [named isEqual: withExtension]
                   && [bundle URLForImageResource: @"missing"] == nil;
        printf("bundle image resource URL: %s\n", passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
