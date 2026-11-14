// Books binds the UIFont system design names to AppKit. dyld stops an app whose AppKit lacks one, so each of the seven
// must be an exported symbol of the process and hold a non-empty string; the ones with an NSFontDescriptor counterpart equal
// it (a descriptor built with either name is read the same way), and the two without differ from every other design.
// The string values themselves are a GUESS (UIFontDesignNames.m).
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

static NSString *constant(const char *name)
{
    NSString *const *symbol = (NSString *const *)dlsym(RTLD_DEFAULT, name);
    expect(symbol != NULL, [NSString stringWithFormat:@"%s is exported", name]);
    NSString *value = *symbol;
    expect([value isKindOfClass:[NSString class]] && [value length] > 0, [NSString stringWithFormat:@"%s holds a string", name]);
    return value;
}

int main(void)
{
    @autoreleasepool
    {
        expect([constant("UIFontDescriptorSystemDesignDefault") isEqual:NSFontDescriptorSystemDesignDefault], @"descriptor default");
        expect([constant("UIFontDescriptorSystemDesignMonospaced") isEqual:NSFontDescriptorSystemDesignMonospaced], @"descriptor monospaced");
        expect([constant("UIFontSystemFontDesignDefault") isEqual:NSFontDescriptorSystemDesignDefault], @"font default");
        expect([constant("UIFontSystemFontDesignRounded") isEqual:NSFontDescriptorSystemDesignRounded], @"font rounded");
        expect([constant("UIFontSystemFontDesignSerif") isEqual:NSFontDescriptorSystemDesignSerif], @"font serif");

        NSArray *others = @[
            NSFontDescriptorSystemDesignDefault, NSFontDescriptorSystemDesignSerif,
            NSFontDescriptorSystemDesignMonospaced, NSFontDescriptorSystemDesignRounded
        ];
        NSString *compact = constant("UIFontSystemFontDesignCompact");
        NSString *condensed = constant("UIFontSystemFontDesignCondensed");
        expect(![others containsObject:compact] && ![others containsObject:condensed], @"compact and condensed are new designs");
        expect(![compact isEqual:condensed], @"compact differs from condensed");
        NSLog(@"appkit-ui-font-system-design: ok");
    }
    return 0;
}
