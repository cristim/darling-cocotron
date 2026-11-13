// CTFontGetLanguageAwareOutsets exists and returns zero outsets (placeholder, see CTFont.m).
#import <AppKit/AppKit.h>
#include <stdlib.h>

int main(void)
{
    @autoreleasepool
    {
        CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 12, NULL);
        if (font == NULL)
        {
            NSLog(@"FAIL: no font");
            exit(1);
        }
        CGRect outsets = CTFontGetLanguageAwareOutsets(font);
        if (!CGRectEqualToRect(outsets, CGRectZero))
        {
            NSLog(@"FAIL: outsets are not zero");
            exit(1);
        }
        CFRelease(font);
        NSLog(@"PASS: CTFontGetLanguageAwareOutsets");
    }
    return 0;
}
