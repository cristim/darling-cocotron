#import <CoreText/CTGlyphInfo.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface DarlingCTGlyphInfo : NSObject {
    NSString *_baseString;
    NSString *_glyphName;
    CGFontIndex _characterIdentifier;
    CTCharacterCollection _characterCollection;
    CGGlyph _glyph;
}

- (instancetype)initWithBaseString:(NSString *)baseString
                         glyphName:(NSString *)glyphName
                             glyph:(CGGlyph)glyph
               characterIdentifier:(CGFontIndex)identifier
               characterCollection:(CTCharacterCollection)collection;
- (CFStringRef)glyphName;
- (CGFontIndex)characterIdentifier;
- (CTCharacterCollection)characterCollection;
- (CGGlyph)glyph;
@end

@implementation DarlingCTGlyphInfo

- (instancetype)initWithBaseString:(NSString *)baseString
                         glyphName:(NSString *)glyphName
                             glyph:(CGGlyph)glyph
               characterIdentifier:(CGFontIndex)identifier
               characterCollection:(CTCharacterCollection)collection
{
    if (!(self = [super init])) return nil;
    _baseString = [baseString copy];
    _glyphName = [glyphName copy];
    _glyph = glyph;
    _characterIdentifier = identifier;
    _characterCollection = collection;
    return self;
}

- (void)dealloc
{
    [_baseString release];
    [_glyphName release];
    [super dealloc];
}

- (CFStringRef)glyphName { return (CFStringRef)_glyphName; }
- (CGFontIndex)characterIdentifier { return _characterIdentifier; }
- (CTCharacterCollection)characterCollection { return _characterCollection; }
- (CGGlyph)glyph { return _glyph; }
- (CFTypeID)_cfTypeID { return CTGlyphInfoGetTypeID(); }

@end

CFTypeID CTGlyphInfoGetTypeID(void)
{
    return (CFTypeID)[DarlingCTGlyphInfo class];
}

CTGlyphInfoRef CTGlyphInfoCreateWithGlyphName(CFStringRef glyphName, CTFontRef font,
                                              CFStringRef baseString)
{
    if (!glyphName || !font || !baseString) return NULL;
    CGGlyph glyph = CTFontGetGlyphWithName(font, glyphName);
    if (!glyph) return NULL;
    return (CTGlyphInfoRef)[[DarlingCTGlyphInfo alloc]
        initWithBaseString:(NSString *)baseString glyphName:(NSString *)glyphName
        glyph:glyph characterIdentifier:glyph
        characterCollection:kCTIdentityMappingCharacterCollection];
}

CTGlyphInfoRef CTGlyphInfoCreateWithGlyph(CGGlyph glyph, CTFontRef font,
                                          CFStringRef baseString)
{
    if (!glyph || !font || !baseString) return NULL;
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (!graphicsFont) return NULL;
    CFStringRef name = CGFontCopyGlyphNameForGlyph(graphicsFont, glyph);
    CGFontRelease(graphicsFont);
    CTGlyphInfoRef info = (CTGlyphInfoRef)[[DarlingCTGlyphInfo alloc]
        initWithBaseString:(NSString *)baseString glyphName:(NSString *)name
        glyph:glyph characterIdentifier:glyph
        characterCollection:kCTIdentityMappingCharacterCollection];
    if (name) CFRelease(name);
    return info;
}

CTGlyphInfoRef CTGlyphInfoCreateWithCharacterIdentifier(CGFontIndex cid,
                                                       CTCharacterCollection collection,
                                                       CFStringRef baseString)
{
    if (!baseString) return NULL;
    CGGlyph glyph = collection == kCTIdentityMappingCharacterCollection ? cid : 0;
    return (CTGlyphInfoRef)[[DarlingCTGlyphInfo alloc]
        initWithBaseString:(NSString *)baseString glyphName:nil
        glyph:glyph characterIdentifier:cid characterCollection:collection];
}

CFStringRef CTGlyphInfoGetGlyphName(CTGlyphInfoRef info)
{
    return [(DarlingCTGlyphInfo *)info glyphName];
}

CGFontIndex CTGlyphInfoGetCharacterIdentifier(CTGlyphInfoRef info)
{
    return [(DarlingCTGlyphInfo *)info characterIdentifier];
}

CTCharacterCollection CTGlyphInfoGetCharacterCollection(CTGlyphInfoRef info)
{
    return [(DarlingCTGlyphInfo *)info characterCollection];
}

CGGlyph CTGlyphInfoGetGlyph(CTGlyphInfoRef info)
{
    return [(DarlingCTGlyphInfo *)info glyph];
}
