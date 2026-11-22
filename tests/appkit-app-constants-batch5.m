// Names the dyld collect-missing sweep found Mac Catalyst apps binding to AppKit: NSAccessibilityOpenAction and
// NSAccessibilityDateTimeComponentsAttribute (Calendar), NSApplicationDidChangeOcclusionStateNotification and
// NSImageHintSymbolFont (App Store), NSSharingServiceParametersDefaultRecipientsKey (Calendar). dyld stops an app whose
// AppKit lacks one, so each must be an exported string symbol of the process holding the string a real Mac holds
// (mac-probe darling_probe_a1.txt, macOS 26.1), which the test pins literally.
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
            { "NSAccessibilityOpenAction", "AXOpen" },
            { "NSAccessibilityDateTimeComponentsAttribute", "AXDateTimeComponents" },
            { "NSApplicationDidChangeOcclusionStateNotification", "NSApplicationDidChangeOcclusionStateNotification" },
            { "NSImageHintSymbolFont", "NSImageHintSymbolFont" },
            { "NSSharingServiceParametersDefaultRecipientsKey", "NSSharingServiceParametersDefaultRecipientsKey" },
        };
        for (unsigned i = 0; i < sizeof expected / sizeof *expected; i++)
        {
            NSString *const *symbol = (NSString *const *)dlsym(RTLD_DEFAULT, expected[i].name);
            expect(symbol != NULL, [NSString stringWithFormat:@"%s is exported", expected[i].name]);
            NSString *want = [NSString stringWithUTF8String:expected[i].value];
            expect([*symbol isKindOfClass:[NSString class]] && [*symbol isEqualToString:want],
                   [NSString stringWithFormat:@"%s is \"%@\", got \"%@\"", expected[i].name, want, *symbol]);
        }
        // the header declarations are the exported objects
        expect([NSApplicationDidChangeOcclusionStateNotification isEqualToString:@"NSApplicationDidChangeOcclusionStateNotification"],
               @"notification header declaration");
        expect([NSAccessibilityOpenAction isEqualToString:@"AXOpen"], @"open action header declaration");
        NSLog(@"appkit-app-constants-batch5: ok");
    }
    return 0;
}
