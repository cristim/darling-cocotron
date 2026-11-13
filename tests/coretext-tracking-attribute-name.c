#include <CoreText/CoreText.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// kCTTrackingAttributeName (CTStringAttributes.h): the attribute name for a run's tracking, a CFNumber of
// points added after each glyph. Here only the name is checked: it is a string, distinct from other
// attribute names, and an attributed string stores and returns a value under it.
int main(void) {
    EXPECT(kCTTrackingAttributeName != NULL && CFGetTypeID(kCTTrackingAttributeName) == CFStringGetTypeID(), "the name is a CFString");
    EXPECT(!CFEqual(kCTTrackingAttributeName, kCTLigatureAttributeName), "tracking is not ligatures");
    EXPECT(!CFEqual(kCTTrackingAttributeName, kCTFontAttributeName), "tracking is not the font attribute");

    CFMutableAttributedStringRef text = CFAttributedStringCreateMutable(NULL, 0);
    CFAttributedStringReplaceString(text, CFRangeMake(0, 0), CFSTR("abc"));
    double tracking = 1.5;
    CFNumberRef number = CFNumberCreate(NULL, kCFNumberDoubleType, &tracking);
    CFAttributedStringSetAttribute(text, CFRangeMake(0, 3), kCTTrackingAttributeName, number);
    CFTypeRef stored = CFAttributedStringGetAttribute(text, 1, kCTTrackingAttributeName, NULL);
    EXPECT(stored != NULL && CFEqual(stored, number), "the attribute round-trips through an attributed string");
    CFRelease(number);
    CFRelease(text);
    printf("PASS: kCTTrackingAttributeName\n");
    return 0;
}
