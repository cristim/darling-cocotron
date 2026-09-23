#ifndef COCORETEXT_CTGLYPHINFO_H
#define COCORETEXT_CTGLYPHINFO_H

#import <CoreText/CTFont.h>
#import <CoreText/CoreTextExport.h>
#import <CoreGraphics/CGFont.h>

CF_IMPLICIT_BRIDGING_ENABLED

typedef const struct CF_BRIDGED_TYPE(id) __CTGlyphInfo *CTGlyphInfoRef;

typedef CF_ENUM(uint32_t, CTCharacterCollection) {
    kCTIdentityMappingCharacterCollection = 0,
    kCTAdobeCNS1CharacterCollection = 1,
    kCTAdobeGB1CharacterCollection = 2,
    kCTAdobeJapan1CharacterCollection = 3,
    kCTAdobeJapan2CharacterCollection = 4,
    kCTAdobeKorea1CharacterCollection = 5,
};

CORETEXT_EXPORT CFTypeID CTGlyphInfoGetTypeID(void);
CORETEXT_EXPORT CTGlyphInfoRef _Nullable CTGlyphInfoCreateWithGlyphName(
    CFStringRef glyphName, CTFontRef font, CFStringRef baseString);
CORETEXT_EXPORT CTGlyphInfoRef _Nullable CTGlyphInfoCreateWithGlyph(
    CGGlyph glyph, CTFontRef font, CFStringRef baseString);
CORETEXT_EXPORT CTGlyphInfoRef _Nullable CTGlyphInfoCreateWithCharacterIdentifier(
    CGFontIndex cid, CTCharacterCollection collection, CFStringRef baseString);
CORETEXT_EXPORT CFStringRef _Nullable CTGlyphInfoGetGlyphName(CTGlyphInfoRef glyphInfo);
CORETEXT_EXPORT CGFontIndex CTGlyphInfoGetCharacterIdentifier(CTGlyphInfoRef glyphInfo);
CORETEXT_EXPORT CTCharacterCollection CTGlyphInfoGetCharacterCollection(CTGlyphInfoRef glyphInfo);
CORETEXT_EXPORT CGGlyph CTGlyphInfoGetGlyph(CTGlyphInfoRef glyphInfo);

CF_IMPLICIT_BRIDGING_DISABLED

#endif
