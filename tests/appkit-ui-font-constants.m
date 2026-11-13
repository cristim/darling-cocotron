// UIFont* names that UIKit-for-Mac applications bind to AppKit: the weight
// scale is ordered and the string constants equal their NS counterparts, so a
// descriptor built with either name is read the same way.
#import <AppKit/AppKit.h>
#include <stdlib.h>

APPKIT_EXPORT const CGFloat UIFontWeightUltraLight, UIFontWeightThin, UIFontWeightLight,
    UIFontWeightRegular, UIFontWeightMedium, UIFontWeightSemibold, UIFontWeightBold,
    UIFontWeightHeavy, UIFontWeightBlack;
APPKIT_EXPORT NSString *const UIFontDescriptorTraitsAttribute,
    *const UIFontDescriptorFeatureSettingsAttribute, *const UIFontDescriptorTextStyleAttribute,
    *const UIFontFeatureTypeIdentifierKey, *const UIFontFeatureSelectorIdentifierKey,
    *const UIFontWeightTrait, *const UIFontDescriptorSystemDesignSerif,
    *const UIFontDescriptorSystemDesignRounded;

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
        CGFloat scale[] = {UIFontWeightUltraLight, UIFontWeightThin,   UIFontWeightLight,
                           UIFontWeightRegular,    UIFontWeightMedium, UIFontWeightSemibold,
                           UIFontWeightBold,       UIFontWeightHeavy,  UIFontWeightBlack};
        for (int i = 1; i < 9; i++)
            expect(scale[i] > scale[i - 1], @"weights increase from ultra light to black");
        expect(UIFontWeightRegular == 0.0, @"regular is zero");
        expect(UIFontWeightUltraLight > -1.0 && UIFontWeightBlack < 1.0,
               @"weights stay inside the -1..1 scale");

        expect([UIFontDescriptorTraitsAttribute isEqual:NSFontTraitsAttribute], @"traits attribute");
        expect([UIFontDescriptorFeatureSettingsAttribute isEqual:NSFontFeatureSettingsAttribute],
               @"feature settings attribute");
        expect([UIFontFeatureTypeIdentifierKey isEqual:NSFontFeatureTypeIdentifierKey], @"type id key");
        expect([UIFontFeatureSelectorIdentifierKey isEqual:NSFontFeatureSelectorIdentifierKey],
               @"selector id key");
        expect([UIFontWeightTrait isEqual:NSFontWeightTrait], @"weight trait");
        expect([UIFontDescriptorSystemDesignSerif isEqual:NSFontDescriptorSystemDesignSerif], @"serif");
        expect([UIFontDescriptorSystemDesignRounded isEqual:NSFontDescriptorSystemDesignRounded],
               @"rounded");
        expect([UIFontDescriptorTextStyleAttribute length] > 0, @"text style attribute is set");
        NSLog(@"PASS: UIFont constants");
    }
    return 0;
}
