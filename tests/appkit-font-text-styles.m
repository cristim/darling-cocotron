// NSFontTextStyle constants: every documented style is exported, is an
// NSString, and the eleven values are distinct (a fault of a shared literal
// would make two styles compare equal).
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

int main(void)
{
    @autoreleasepool
    {
        NSFontTextStyle styles[] = {
            NSFontTextStyleLargeTitle, NSFontTextStyleTitle1, NSFontTextStyleTitle2,
            NSFontTextStyleTitle3,     NSFontTextStyleHeadline, NSFontTextStyleSubheadline,
            NSFontTextStyleBody,       NSFontTextStyleCallout,  NSFontTextStyleFootnote,
            NSFontTextStyleCaption1,   NSFontTextStyleCaption2,
        };
        NSMutableSet *seen = [NSMutableSet set];
        for (size_t i = 0; i < sizeof(styles) / sizeof(styles[0]); i++)
        {
            expect([styles[i] isKindOfClass:[NSString class]], @"style is an NSString");
            expect([styles[i] length] > 0, @"style is not empty");
            [seen addObject:styles[i]];
        }
        expect([seen count] == 11, @"the eleven styles are distinct");
        NSLog(@"PASS: NSFontTextStyle");
    }
    return 0;
}
