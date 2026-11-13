// Links CoreText without AppKit. Notes imports CTFontManagerEnableSystemVisibleFonts from CoreText and calls it while launching;
// without a definition dyld stops the app before any app code runs. The signature is a guess (see CTFontManager.m): the name must
// exist and calling it must return instead of stopping the process.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdlib.h>

int main(void)
{
    @autoreleasepool
    {
        bool (*enable)(void) = (bool (*)(void))dlsym(RTLD_DEFAULT, "CTFontManagerEnableSystemVisibleFonts");
        if (!enable)
        {
            NSLog(@"FAIL: CTFontManagerEnableSystemVisibleFonts is defined");
            return 1;
        }
        if (!enable())
        {
            NSLog(@"FAIL: CTFontManagerEnableSystemVisibleFonts reports done");
            return 1;
        }
        // fonts stay listed afterwards
        CFArrayRef families = CTFontManagerCopyAvailableFontFamilyNames();
        if (!families)
        {
            NSLog(@"FAIL: font families are still listed");
            return 1;
        }
        CFRelease(families);
        NSLog(@"coretext-font-manager-system-visible-fonts: ok");
    }
    return 0;
}
