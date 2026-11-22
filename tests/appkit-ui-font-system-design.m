// The UIFont system design names Books, Podcasts, Journal and TV bind to AppKit. dyld stops an app whose AppKit lacks one, so
// each must be an exported string symbol of the process, and each holds the string a real Mac holds (mac-probe
// darling_probe_a1.txt, macOS 26.1), which the test pins literally.
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
        static const struct { const char *name; const char *value; } expected[] = {
            { "UIFontDescriptorSystemDesignDefault", "NSCTFontUIFontDesignDefault" },
            { "UIFontDescriptorSystemDesignMonospaced", "NSCTFontUIFontDesignMonospaced" },
            { "UIFontDescriptorFamilyAttribute", "NSFontFamilyAttribute" },
            { "UIFontDescriptorNameAttribute", "NSFontNameAttribute" },
            { "UIFontDescriptorSizeAttribute", "NSFontSizeAttribute" },
            { "UIFontSystemFontDesignCompact", "NSCTFontUIFontDesignCompact" },
            { "UIFontSystemFontDesignCondensed", "NSCTFontUIFontDesignCondensed" },
            { "UIFontSystemFontDesignDefault", "NSCTFontUIFontDesignDefault" },
            { "UIFontSystemFontDesignRounded", "NSCTFontUIFontDesignRounded" },
            { "UIFontSystemFontDesignSerif", "NSCTFontUIFontDesignSerif" },
            { "UIFontSystemFontDesignTrait", "NSCTFontUIFontDesignTrait" },
            { "NSFontSystemDesignRounded", "NSCTFontUIFontDesignRounded" },
        };
        for (unsigned i = 0; i < sizeof expected / sizeof *expected; i++)
        {
            NSString *const *symbol = (NSString *const *)dlsym(RTLD_DEFAULT, expected[i].name);
            expect(symbol != NULL, [NSString stringWithFormat:@"%s is exported", expected[i].name]);
            NSString *want = [NSString stringWithUTF8String:expected[i].value];
            expect([*symbol isKindOfClass:[NSString class]] && [*symbol isEqualToString:want],
                   [NSString stringWithFormat:@"%s is \"%@\", got \"%@\"", expected[i].name, want, *symbol]);
        }
        NSLog(@"appkit-ui-font-system-design: ok");
    }
    return 0;
}
