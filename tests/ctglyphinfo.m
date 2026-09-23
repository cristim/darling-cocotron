#import <CoreText/CoreText.h>

int main(void)
{
    CTGlyphInfoRef info = CTGlyphInfoCreateWithCharacterIdentifier(
        42, kCTIdentityMappingCharacterCollection, CFSTR("A"));
    if (!info) return 1;

    int failed = CFGetTypeID(info) != CTGlyphInfoGetTypeID()
        || CTGlyphInfoGetCharacterIdentifier(info) != 42
        || CTGlyphInfoGetCharacterCollection(info) != kCTIdentityMappingCharacterCollection
        || CTGlyphInfoGetGlyph(info) != 42;

    CFRelease(info);
    return failed;
}
