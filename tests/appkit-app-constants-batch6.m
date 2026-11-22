// String constants that stock apps bind to AppKit (Mail, Notes, TV, Freeform, Photos, Reminders, VoiceOver Utility, Journal).
// dyld stops an app whose AppKit lacks one, so each must be an exported string symbol of the process holding the string a
// real Mac holds (mac-probe darling_probe_a1.txt, macOS 26.1), which the test pins literally, so a name that carries its own
// name by guess and not by observation fails it.
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

int main(void)
{
    @autoreleasepool
    {
        static const struct { const char *name; const char *value; } expected[] = {
            { "NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification", "NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification" },
            { "NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification", "NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification" },
            { "NSPopUpButtonCellWillPopUpNotification", "NSPopUpButtonCellWillPopUpNotification" },
            { "NSMenuDidCompleteInteractionNotification", "NSMenuDidCompleteInteractionNotification" },
            { "NSControlWillBeginContinuousTrackingNotification", "NSControlWillBeginContinuousTrackingNotification" },
            { "NSControlDidEndContinuousTrackingNotification", "NSControlDidEndContinuousTrackingNotification" },
            { "NSWorkspaceAccessibilityFocusedElementDidChangeNotification", "NSWorkspaceAccessibilityFocusedElementDidChangeNotification" },
            { "NSAccessibilityChildrenInNavigationOrderAttribute", "AXChildrenInNavigationOrder" },
            { "NSAccessibilityFocusedElementKey", "NSAccessibilityFocusedElementKey" },
            { "NSAccessibilityPopoverRole", "AXPopover" },
            { "NSAccessibilityEnhancedUserInterfaceAttribute", "AXEnhancedUserInterface" },
            { "NSToolbarWritingToolsItemIdentifier", "NSToolbarWritingToolsItem" },
            { "NSTouchBarItemIdentifierCandidateList", "NSTouchBarItemIdentifierCandidateList" },
            { "NSTouchBarItemIdentifierTextAlignment", "NSTouchBarItemIdentifierTextAlignment" },
            { "NSTouchBarItemIdentifierTextColorPicker", "NSTouchBarItemIdentifierTextColorPicker" },
            { "NSTouchBarItemIdentifierTextList", "NSTouchBarItemIdentifierTextList" },
            { "NSTouchBarItemIdentifierTextStyle", "NSTouchBarItemIdentifierTextStyle" },
            { "NSInspectorBarFontFamilyItemIdentifier", "NSInspectorBarFontFamilyItemIdentifier" },
            { "NSInspectorBarFontSizeItemIdentifier", "NSInspectorBarFontSizeItemIdentifier" },
            { "NSInspectorBarFontStyleItemIdentifier", "NSInspectorBarFontStyleItemIdentifier" },
            { "NSInspectorBarSpaceItemIdentifier", "NSInspectorBarSpaceItemIdentifier" },
            { "NSInspectorBarTextAlignmentItemIdentifier", "NSInspectorBarTextAlignmentItemIdentifier" },
            { "NSInspectorBarTextBackgroundColorItemIdentifier", "NSInspectorBarTextBackgroundColorItemIdentifier" },
            { "NSInspectorBarTextForegroundColorItemIdentifier", "NSInspectorBarTextForegroundColorItemIdentifier" },
            { "NSInspectorBarTextListItemIdentifier", "NSInspectorBarTextListItemIdentifier" },
            { "NSAboutPanelOptionCredits", "Credits" },
            { "NSTextListMarkerHyphen", "{hyphen}" },
            { "NSFontCollectionUser", "com.apple.UserFonts" },
            { "NSFullScreenModeAllScreens", "NSFullScreenModeAllScreens" },
            { "NSImageNameToolbarBookmarks", "NSToolbarBookmarks" },
            { "NSTextMovementUserInfoKey", "NSTextMovement" },
            { "NSToolbarItemKey", "item" },
            { "NSOutlineViewShowHideButtonKey", "NSOutlineViewShowHideButtonKey" },
        };
        for (unsigned i = 0; i < sizeof expected / sizeof *expected; i++)
        {
            NSString *const *symbol = (NSString *const *)dlsym(RTLD_DEFAULT, expected[i].name);
            expect(symbol != NULL, [NSString stringWithFormat:@"%s is exported", expected[i].name]);
            NSString *want = [NSString stringWithUTF8String:expected[i].value];
            expect([*symbol isKindOfClass:[NSString class]] && [*symbol isEqualToString:want],
                   [NSString stringWithFormat:@"%s is \"%@\", got \"%@\"", expected[i].name, want, *symbol]);
        }
        NSLog(@"appkit-app-constants-batch6: ok (%u names)", (unsigned)(sizeof expected / sizeof *expected));
    }
    return 0;
}
