// Names the dyld collect-missing sweep found Mac Catalyst apps binding to AppKit: NSAccessibilityOpenAction and
// NSAccessibilityDateTimeComponentsAttribute (Calendar), NSApplicationDidChangeOcclusionStateNotification and
// NSImageHintSymbolFont (App Store), NSSharingServiceParametersDefaultRecipientsKey (Calendar). dyld stops an app whose
// AppKit lacks one, so each must be an exported symbol of the process holding a non-empty string, and they must differ from
// each other and from the constants next to them. The string values are a GUESS (the names themselves).
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
        NSString *open = constant("NSAccessibilityOpenAction");
        NSString *dateTime = constant("NSAccessibilityDateTimeComponentsAttribute");
        NSString *occlusion = constant("NSApplicationDidChangeOcclusionStateNotification");
        NSString *symbolFont = constant("NSImageHintSymbolFont");
        NSString *recipients = constant("NSSharingServiceParametersDefaultRecipientsKey");

        NSSet *all = [NSSet setWithObjects:open, dateTime, occlusion, symbolFont, recipients, nil];
        expect([all count] == 5, @"the five names are distinct");
        expect(![open isEqual:NSAccessibilityPressAction] && ![open isEqual:NSAccessibilityShowMenuAction], @"open differs from the other actions");
        expect(![occlusion isEqual:NSApplicationDidBecomeActiveNotification] &&
               ![occlusion isEqual:NSWindowDidChangeOcclusionStateNotification], @"the application occlusion notification differs from its siblings");
        expect(![symbolFont isEqual:NSImageHintSymbolScale], @"symbol font differs from symbol scale");

        // the header declarations are the exported objects
        expect([NSApplicationDidChangeOcclusionStateNotification isEqual:occlusion], @"notification header declaration");
        expect([NSAccessibilityOpenAction isEqual:open], @"open action header declaration");
        NSLog(@"appkit-app-constants-batch5: ok");
    }
    return 0;
}
