#include <CoreText/CoreText.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CTFontManagerUnregisterFontsForURL (CTFontManager.h): fails for a URL whose fonts are not registered, with
// kCTFontManagerErrorNotRegistered and the URL in the error's user info. Nothing is registered in this process.
int main(void) {
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, CFSTR("/nonexistent/Example.ttf"), kCFURLPOSIXPathStyle, false);
    CFErrorRef error = NULL;
    bool result = CTFontManagerUnregisterFontsForURL(url, kCTFontManagerScopeProcess, &error);
    EXPECT(!result, "an unregistered URL does not unregister");
    EXPECT(error != NULL, "the error is returned");
    EXPECT(CFEqual(CFErrorGetDomain(error), kCTFontManagerErrorDomain), "the error is in the font manager domain");
    EXPECT(CFErrorGetCode(error) == kCTFontManagerErrorNotRegistered, "the error code is not-registered");
    CFDictionaryRef info = CFErrorCopyUserInfo(error);
    CFArrayRef urls = info ? CFDictionaryGetValue(info, kCTFontManagerErrorFontURLsKey) : NULL;
    EXPECT(urls != NULL && CFArrayGetCount(urls) == 1 && CFEqual(CFArrayGetValueAtIndex(urls, 0), url), "the error lists the URL");
    CFRelease(info);
    CFRelease(error);
    EXPECT(!CTFontManagerUnregisterFontsForURL(url, kCTFontManagerScopeProcess, NULL), "a NULL error pointer is allowed");
    CFRelease(url);
    printf("PASS: CTFontManagerUnregisterFontsForURL\n");
    return 0;
}
