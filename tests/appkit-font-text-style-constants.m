// Guest apps bind the NSFontTextStyle constants to AppKit's install name (Notes: _NSFontTextStyleBody). dyld stops an app
// whose AppKit lacks one, so each of the eleven must be an exported symbol of the process, hold a string, and differ from the
// others. The string values are not checked: they are a GUESS (NSTextSystemConstants.m).
#import <AppKit/AppKit.h>
#include <dlfcn.h>
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
        NSArray<NSString *> *names = @[
            @"NSFontTextStyleLargeTitle", @"NSFontTextStyleTitle1", @"NSFontTextStyleTitle2", @"NSFontTextStyleTitle3",
            @"NSFontTextStyleHeadline", @"NSFontTextStyleSubheadline", @"NSFontTextStyleBody", @"NSFontTextStyleCallout",
            @"NSFontTextStyleFootnote", @"NSFontTextStyleCaption1", @"NSFontTextStyleCaption2"
        ];
        NSMutableSet *values = [NSMutableSet set];
        for (NSString *name in names)
        {
            NSString *const *symbol = (NSString *const *)dlsym(RTLD_DEFAULT, [name UTF8String]);
            expect(symbol != NULL, [NSString stringWithFormat:@"%@ is exported", name]);
            NSString *value = *symbol;
            expect([value isKindOfClass:[NSString class]] && [value length] > 0, [NSString stringWithFormat:@"%@ holds a string", name]);
            expect(![values containsObject:value], [NSString stringWithFormat:@"%@ differs from the others", name]);
            [values addObject:value];
        }
        // the typed declarations in the header are the same objects
        NSFontTextStyle body = NSFontTextStyleBody;
        expect([body isEqualToString:*(NSString *const *)dlsym(RTLD_DEFAULT, "NSFontTextStyleBody")], @"header declaration is the exported symbol");
        NSLog(@"appkit-font-text-style-constants: ok");
    }
    return 0;
}
