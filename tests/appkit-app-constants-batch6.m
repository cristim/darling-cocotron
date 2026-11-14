// String constants that stock apps bind to AppKit (Mail, Notes, TV, Freeform, Photos, Reminders, VoiceOver Utility). dyld
// stops an app whose AppKit lacks one, so each must be an exported symbol of the process holding a non-empty string, and no
// two may share a value. The four with a source outside this tree (the two HDR notifications from a real Mac, and
// NSPopUpButtonCellWillPopUpNotification and NSFontCollectionUser from GNUstep) are also checked against it: each holds its
// own name. The values of the others are a GUESS (NSAppConstantsBatch6.m).
#import <Foundation/Foundation.h>
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
        static const char *const names[] = {
            "NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification",
            "NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification",
            "NSPopUpButtonCellWillPopUpNotification",
            "NSMenuDidCompleteInteractionNotification",
            "NSControlWillBeginContinuousTrackingNotification",
            "NSControlDidEndContinuousTrackingNotification",
            "NSWorkspaceAccessibilityFocusedElementDidChangeNotification",
            "NSAccessibilityChildrenInNavigationOrderAttribute",
            "NSAccessibilityFocusedElementKey",
            "NSAccessibilityPopoverRole",
            "NSAccessibilityEnhancedUserInterfaceAttribute",
            "NSToolbarWritingToolsItemIdentifier",
            "NSTouchBarItemIdentifierCandidateList",
            "NSTouchBarItemIdentifierTextAlignment",
            "NSTouchBarItemIdentifierTextColorPicker",
            "NSTouchBarItemIdentifierTextList",
            "NSTouchBarItemIdentifierTextStyle",
            "NSInspectorBarFontFamilyItemIdentifier",
            "NSInspectorBarFontSizeItemIdentifier",
            "NSInspectorBarFontStyleItemIdentifier",
            "NSInspectorBarSpaceItemIdentifier",
            "NSInspectorBarTextAlignmentItemIdentifier",
            "NSInspectorBarTextBackgroundColorItemIdentifier",
            "NSInspectorBarTextForegroundColorItemIdentifier",
            "NSInspectorBarTextListItemIdentifier",
            "NSAboutPanelOptionCredits",
            "NSTextListMarkerHyphen",
            "NSFontCollectionUser",
            "NSFullScreenModeAllScreens"
        };
        static const char *const sourced[] = {
            "NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification",
            "NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification",
            "NSPopUpButtonCellWillPopUpNotification",
            "NSFontCollectionUser"
        };
        NSMutableSet *seen = [NSMutableSet set];
        for (unsigned i = 0; i < sizeof names / sizeof *names; i++)
        {
            NSString *value = constant(names[i]);
            expect(![seen containsObject:value], [NSString stringWithFormat:@"%s differs from the others", names[i]]);
            [seen addObject:value];
        }
        for (unsigned i = 0; i < sizeof sourced / sizeof *sourced; i++)
            expect([constant(sourced[i]) isEqualToString:[NSString stringWithUTF8String:sourced[i]]],
                   [NSString stringWithFormat:@"%s holds its own name", sourced[i]]);
        NSLog(@"appkit-app-constants-batch6: ok (%u names)", (unsigned)(sizeof names / sizeof *names));
    }
    return 0;
}
