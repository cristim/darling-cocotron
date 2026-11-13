#include <CoreText/CoreText.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CTFontDescriptorCreateForUIType (prototype from WebKit's CoreTextSPI.h): the descriptor of the UI font of
// a type and size. It describes the font CTFontCreateUIFontForLanguage makes for the same arguments, which
// has a font for every UI font type; a size of 0 takes the default size of the type.
static int check(CTFontUIFontType type, CGFloat size, CGFloat expectedSize) {
    CTFontRef font = CTFontCreateUIFontForLanguage(type, size, NULL);
    EXPECT(font != NULL, "every UI font type has a font");
    CTFontDescriptorRef descriptor = CTFontDescriptorCreateForUIType(type, size, NULL);
    EXPECT(descriptor != NULL, "every UI font type has a descriptor");
    CFStringRef fontName = CTFontCopyPostScriptName(font);
    CFTypeRef descriptorName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
    EXPECT(descriptorName != NULL && CFEqual(descriptorName, fontName), "the descriptor names the UI font");
    CFTypeRef descriptorSize = CTFontDescriptorCopyAttribute(descriptor, kCTFontSizeAttribute);
    double value = 0;
    EXPECT(descriptorSize != NULL && CFNumberGetValue(descriptorSize, kCFNumberDoubleType, &value) && value == CTFontGetSize(font), "the descriptor has the UI font's size");
    EXPECT(CTFontGetSize(font) == expectedSize, "the font has the requested or default size");
    CFRelease(fontName); CFRelease(descriptorName); CFRelease(descriptorSize); CFRelease(descriptor); CFRelease(font);
    return 0;
}

// The PostScript name of the font of a UI font type at its default size.
static CFStringRef nameOf(CTFontUIFontType type) {
    CTFontRef font = CTFontCreateUIFontForLanguage(type, 0, NULL);
    CFStringRef name = font != NULL ? CTFontCopyPostScriptName(font) : NULL;
    if (font != NULL) CFRelease(font);
    return name;
}

int main(void) {
    int bad = 0;
    // The emphasized types take a bold face and the fixed-pitch type a fixed-pitch one: neither is the system face.
    CFStringRef sys = nameOf(kCTFontUIFontSystem), emph = nameOf(kCTFontUIFontEmphasizedSystem), fixed = nameOf(kCTFontUIFontUserFixedPitch);
    EXPECT(sys != NULL && emph != NULL && fixed != NULL, "the system, emphasized and fixed-pitch fonts have names");
    EXPECT(!CFEqual(sys, emph), "the emphasized system font is not the regular face");
    EXPECT(!CFEqual(sys, fixed), "the user fixed-pitch font is not the system face");
    EXPECT(CFEqual(nameOf(kCTFontUIFontAlertHeader), emph) && CFEqual(nameOf(kCTFontUIFontSmallEmphasizedSystem), emph), "alert header and small emphasized share the bold face");
    EXPECT(CFEqual(nameOf(kCTFontUIFontSmallSystem), sys) && CFEqual(nameOf(kCTFontUIFontMiniSystem), sys), "small and mini system use the regular face");
    bad += check(kCTFontUIFontSystem, 17, 17);
    bad += check(kCTFontUIFontSystem, 0, 13);
    bad += check(kCTFontUIFontSmallSystem, 0, 11);
    bad += check(kCTFontUIFontMiniSystem, 0, 9);
    bad += check(kCTFontUIFontEmphasizedSystem, 0, 13);
    bad += check(kCTFontUIFontLabel, 0, 10);
    bad += check(kCTFontUIFontToolTip, 0, 10);
    bad += check(kCTFontUIFontMessage, 0, 13);
    bad += check(kCTFontUIFontMenuItem, 13, 13);
    bad += check(kCTFontUIFontMenuTitle, 0, 12);
    bad += check(kCTFontUIFontWindowTitle, 14, 14);
    bad += check(kCTFontUIFontUserFixedPitch, 0, 12);
    EXPECT(CTFontCreateUIFontForLanguage(kCTFontUIFontNone, 12, NULL) == NULL, "no UI font type, no font");
    EXPECT(CTFontDescriptorCreateForUIType(kCTFontUIFontNone, 12, NULL) == NULL, "no UI font type, no descriptor");
    if (bad == 0) printf("PASS: CTFontDescriptorCreateForUIType\n");
    return bad;
}
