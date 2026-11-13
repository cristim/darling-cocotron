// NSFontWeight constants hold values on the -1..1 scale, not integers read from bit
// patterns, and equal the UIFontWeight constants of the same name.
#import <AppKit/AppKit.h>
#include <math.h>
#include <stdlib.h>

APPKIT_EXPORT const CGFloat UIFontWeightUltraLight, UIFontWeightThin, UIFontWeightLight,
    UIFontWeightRegular, UIFontWeightMedium, UIFontWeightSemibold, UIFontWeightBold,
    UIFontWeightHeavy, UIFontWeightBlack;

static void expect(NSString *name, CGFloat actual, CGFloat expected)
{
    NSLog(@"%@ = %g", name, (double)actual);
    if (fabs(actual - expected) > 1e-6)
    {
        NSLog(@"FAIL: %@ is %g, expected %g", name, (double)actual, (double)expected);
        exit(1);
    }
}

int main(void)
{
    expect(@"NSFontWeightUltraLight", NSFontWeightUltraLight, -0.8);
    expect(@"NSFontWeightThin", NSFontWeightThin, -0.6);
    expect(@"NSFontWeightLight", NSFontWeightLight, -0.4);
    expect(@"NSFontWeightRegular", NSFontWeightRegular, 0.0);
    expect(@"NSFontWeightMedium", NSFontWeightMedium, 0.23);
    expect(@"NSFontWeightSemibold", NSFontWeightSemibold, 0.3);
    expect(@"NSFontWeightBold", NSFontWeightBold, 0.4);
    expect(@"NSFontWeightHeavy", NSFontWeightHeavy, 0.56);
    expect(@"NSFontWeightBlack", NSFontWeightBlack, 0.62);
    expect(@"UIFontWeightUltraLight", UIFontWeightUltraLight, NSFontWeightUltraLight);
    expect(@"UIFontWeightThin", UIFontWeightThin, NSFontWeightThin);
    expect(@"UIFontWeightLight", UIFontWeightLight, NSFontWeightLight);
    expect(@"UIFontWeightRegular", UIFontWeightRegular, NSFontWeightRegular);
    expect(@"UIFontWeightMedium", UIFontWeightMedium, NSFontWeightMedium);
    expect(@"UIFontWeightSemibold", UIFontWeightSemibold, NSFontWeightSemibold);
    expect(@"UIFontWeightBold", UIFontWeightBold, NSFontWeightBold);
    expect(@"UIFontWeightHeavy", UIFontWeightHeavy, NSFontWeightHeavy);
    expect(@"UIFontWeightBlack", UIFontWeightBlack, NSFontWeightBlack);
    NSLog(@"PASS");
    return 0;
}
