/* Copyright (c) 2008 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <CoreText/CTFont.h>
#import <CoreText/CoreText.h>
#import <CoreText/KTFont.h>
#import <Foundation/NSException.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <objc/runtime.h>
#import <Onyx2D/O2Font_freetype.h>
#include <pthread.h>

#ifdef DARLING
#define __linux__
#endif
#import <ft2build.h>
#import FT_FREETYPE_H
#import FT_OUTLINE_H
#ifdef DARLING
#undef __linux__
#endif

const CFStringRef kCTFontCopyrightNameKey = CFSTR("CTFontCopyrightName");
const CFStringRef kCTFontFamilyNameKey = CFSTR("CTFontFamilyName");
const CFStringRef kCTFontSubFamilyNameKey = CFSTR("CTFontSubFamilyName");
const CFStringRef kCTFontStyleNameKey = CFSTR("CTFontSubFamilyName");
const CFStringRef kCTFontUniqueNameKey = CFSTR("CTFontUniqueName");
const CFStringRef kCTFontFullNameKey = CFSTR("CTFontFullName");
const CFStringRef kCTFontVersionNameKey = CFSTR("CTFontVersionName");
const CFStringRef kCTFontPostScriptNameKey = CFSTR("CTFontPostScriptName");
const CFStringRef kCTFontTrademarkNameKey = CFSTR("CTFontTrademarkName");
const CFStringRef kCTFontManufacturerNameKey = CFSTR("CTFontManufacturerName");
const CFStringRef kCTFontDesignerNameKey = CFSTR("CTFontDesignerName");
const CFStringRef kCTFontDescriptionNameKey = CFSTR("CTFontDescriptionName");
const CFStringRef kCTFontVendorURLNameKey = CFSTR("CTFontVendorURLName");
const CFStringRef kCTFontDesignerURLNameKey = CFSTR("CTFontDesignerURLName");
const CFStringRef kCTFontLicenseNameKey = CFSTR("CTFontLicenseNameName");
const CFStringRef kCTFontLicenseURLNameKey = CFSTR("CTFontLicenseURLName");
const CFStringRef kCTFontSampleTextNameKey = CFSTR("CTFontSampleTextName");
const CFStringRef kCTFontPostScriptCIDNameKey = CFSTR("CTFontPostScriptCIDName");

const CFStringRef kCTFontVariationAxisIdentifierKey = CFSTR("NSCTVariationAxisIdentifier");
const CFStringRef kCTFontVariationAxisMinimumValueKey = CFSTR("NSCTVariationAxisMinimumValue");
const CFStringRef kCTFontVariationAxisMaximumValueKey = CFSTR("NSCTVariationAxisMaximumValue");
const CFStringRef kCTFontVariationAxisDefaultValueKey = CFSTR("NSCTVariationAxisDefaultValue");
const CFStringRef kCTFontVariationAxisNameKey = CFSTR("NSCTVariationAxisName");
const CFStringRef kCTFontVariationAxisHiddenKey = CFSTR("NSCTVariationAxisHidden");

const CFStringRef kCTFontFeatureTypeIdentifierKey = CFSTR("CTFeatureTypeIdentifier");
const CFStringRef kCTFontFeatureTypeNameKey = CFSTR("CTFeatureTypeName");
const CFStringRef kCTFontFeatureTypeExclusiveKey = CFSTR("CTFeatureTypeExclusive");
const CFStringRef kCTFontFeatureTypeSelectorsKey = CFSTR("CTFeatureTypeSelectors");
const CFStringRef kCTFontFeatureSelectorIdentifierKey = CFSTR("CTFeatureSelectorIdentifier");
const CFStringRef kCTFontFeatureSelectorNameKey = CFSTR("CTFeatureSelectorName");
const CFStringRef kCTFontFeatureSelectorDefaultKey = CFSTR("CTFeatureSelectorDefault");
const CFStringRef kCTFontFeatureSelectorSettingKey = CFSTR("CTFeatureSelectorSetting");
const CFStringRef kCTFontFeatureSampleTextKey = CFSTR("CTFeatureSampleText");
const CFStringRef kCTFontFeatureTooltipTextKey = CFSTR("CTFeatureTooltipText");

static Class fontClass;
static BOOL fontCreated;
static pthread_mutex_t fontClassLock = PTHREAD_MUTEX_INITIALIZER;
static char fontCascadeKey;

static NSArray *fontCascade(CTFontRef font) {
    return objc_getAssociatedObject((id)font, &fontCascadeKey);
}

static void setFontCascade(CTFontRef font, NSArray *cascade) {
    if (font != NULL && [cascade isKindOfClass:[NSArray class]])
        objc_setAssociatedObject((id)font, &fontCascadeKey, cascade,
                                 OBJC_ASSOCIATION_COPY);
}

void _CTFontSetConcreteClass(Class newClass) {
    pthread_mutex_lock(&fontClassLock);
    BOOL conflict = fontCreated || (fontClass != Nil && fontClass != newClass);
    if (!conflict)
        fontClass = newClass;
    pthread_mutex_unlock(&fontClassLock);
    if (conflict)
        [NSException raise: NSInternalInconsistencyException
                    format: @"_CTFontSetConcreteClass(%@): CoreText already creates %@ fonts",
                            newClass, fontClass ?: [KTFont class]];
}

// Every CTFontCreate* function ends here, so all fonts share one class.
static CTFontRef createFont(CGFontRef cgFont, CGFloat size) {
    if (cgFont == NULL)
        return NULL;
    pthread_mutex_lock(&fontClassLock);
    fontCreated = YES;
    Class cls = fontClass ?: [KTFont class];
    pthread_mutex_unlock(&fontClassLock);
    return (CTFontRef)[[cls alloc] initWithFont: cgFont size: size];
}

static CGFontRef graphicsFont(CTFontRef font) {
    return [(id) font cgFont];
}

static CGFloat fontSize(CTFontRef font) {
    return [(id) font pointSize];
}

// Converts a length in font units to points at the font's size.
static CGFloat scaled(CTFontRef font, CGFloat units) {
    int unitsPerEm = CGFontGetUnitsPerEm(graphicsFont(font));
    return unitsPerEm > 0 ? units / unitsPerEm * fontSize(font) : 0;
}

static FT_Face faceForFont(CTFontRef font) {
    return [(O2Font_freetype *) graphicsFont(font) face];
}

CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix)
{
    CGFontRef cgFont = CGFontCreateWithFontName(name);
    if (!cgFont) {
        cgFont = CGFontCreateWithFontName(CFSTR("Helvetica"));
    }
    if (!cgFont) {
        cgFont = CGFontCreateWithFontName(CFSTR(""));
    }
    CTFontRef result = createFont(cgFont, size > 0.0 ? size : 12.0);
    CGFontRelease(cgFont);
    return result;
}

CTFontRef CTFontCreateWithNameAndOptions(CFStringRef name, CGFloat size,
                                         const CGAffineTransform *matrix,
                                         CTFontOptions options)
{
    return CTFontCreateWithName(name, size, matrix);
}

CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef descriptor, CGFloat size,
                                         const CGAffineTransform *matrix)
{
    CFStringRef name = NULL;
    if (descriptor) {
        name = (CFStringRef)[(NSDictionary *)descriptor objectForKey:(id)kCTFontNameAttribute];
        if (!name) {
            name = (CFStringRef)[(NSDictionary *)descriptor objectForKey:(id)kCTFontFamilyNameAttribute];
        }
        if (size <= 0.0) {
            NSNumber *sizeNum = [(NSDictionary *)descriptor objectForKey:(id)kCTFontSizeAttribute];
            if (sizeNum) {
                size = [sizeNum doubleValue];
            }
        }
    }
    CTFontRef result = CTFontCreateWithName(name ?: CFSTR("Helvetica"), size, matrix);
    setFontCascade(result, [(NSDictionary *)descriptor objectForKey:(id)kCTFontCascadeListAttribute]);
    return result;
}

CTFontRef CTFontCreateWithFontDescriptorAndOptions(CTFontDescriptorRef descriptor, CGFloat size,
                                                   const CGAffineTransform *matrix,
                                                   CTFontOptions options)
{
    return CTFontCreateWithFontDescriptor(descriptor, size, matrix);
}

CTFontRef CTFontCreateUIFontForLanguage(CTFontUIFontType uiFontType,
                                        CGFloat size, CFStringRef language)
{
    // Only the menu fonts have a known face here.
    if (uiFontType != kCTFontMenuTitleFontType && uiFontType != kCTFontMenuItemFontType)
        return NULL;
    CGFontRef cgFont = CGFontCreateWithFontName(CFSTR("San Francisco"));
    CTFontRef result = createFont(cgFont, size > 0.0 ? size : 12.0);
    CGFontRelease(cgFont);
    return result;
}

CTFontRef CTFontCreateCopyWithAttributes(CTFontRef font, CGFloat size,
                                         const CGAffineTransform *matrix,
                                         CTFontDescriptorRef attributes)
{
    if (!font) return nil;
    if (size <= 0.0) {
        size = CTFontGetSize(font);
    }
    CTFontRef result = createFont(graphicsFont(font), size);
    NSArray *cascade = [(NSDictionary *)attributes objectForKey:(id)kCTFontCascadeListAttribute];
    setFontCascade(result, cascade ?: fontCascade(font));
    return result;
}

CTFontRef CTFontCreateCopyWithSymbolicTraits(CTFontRef font, CGFloat size,
                                             const CGAffineTransform *matrix,
                                             CTFontSymbolicTraits symTraitValue, 
                                             CTFontSymbolicTraits symTraitMask)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CTFontRef CTFontCreateCopyWithFamily(CTFontRef font, CGFloat size,
                                     const CGAffineTransform *matrix, CFStringRef family)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CTFontRef CTFontCreateForString(CTFontRef currentFont, CFStringRef string, CFRange range)
{
    return CTFontCreateForStringWithLanguage(currentFont, string, range, NULL);
}

CTFontRef CTFontCreateForStringWithLanguage(CTFontRef currentFont, CFStringRef string,
                                            CFRange range, CFStringRef language)
{
    if (currentFont == NULL || string == NULL || range.location < 0 ||
        range.length < 0 || range.location > CFStringGetLength(string) ||
        range.length > CFStringGetLength(string) - range.location)
        return NULL;
    if (range.length == 0)
        return (CTFontRef)CFRetain(currentFont);
    if ((size_t)range.length > SIZE_MAX / sizeof(uint32_t))
        return NULL;

    UniChar *characters = calloc((size_t)range.length, sizeof(*characters));
    uint32_t *codePoints = calloc((size_t)range.length, sizeof(*codePoints));
    if (characters == NULL || codePoints == NULL) {
        free(characters);
        free(codePoints);
        return NULL;
    }
    CFStringGetCharacters(string, range, characters);
    FT_Face baseFace = faceForFont(currentFont);
    bool covered = baseFace != NULL;
    size_t count = 0;
    for (CFIndex i = 0; i < range.length; i++) {
        uint32_t scalar = characters[i];
        if (scalar >= 0xD800 && scalar <= 0xDBFF && i + 1 < range.length &&
            characters[i + 1] >= 0xDC00 && characters[i + 1] <= 0xDFFF) {
            scalar = 0x10000 + ((scalar - 0xD800) << 10) +
                    (characters[++i] - 0xDC00);
        } else if (scalar >= 0xD800 && scalar <= 0xDFFF) {
            free(characters);
            free(codePoints);
            return NULL;
        }
        codePoints[count++] = scalar;
        FT_UInt glyph = baseFace != NULL ? FT_Get_Char_Index(baseFace, scalar) : 0;
        if (glyph == 0 || glyph > UINT16_MAX)
            covered = false;
    }
    free(characters);
    if (covered) {
        free(codePoints);
        return (CTFontRef)CFRetain(currentFont);
    }

    // Explicit descriptors are tried in caller-supplied order. Do not recurse
    // through their own cascade lists: each candidate must itself cover input.
    for (id descriptor in fontCascade(currentFont)) {
        if (![descriptor isKindOfClass:[NSDictionary class]])
            continue;
        CTFontRef candidate = CTFontCreateWithFontDescriptor(
                (CTFontDescriptorRef)descriptor, CTFontGetSize(currentFont), NULL);
        if (candidate == NULL)
            continue;
        FT_Face face = faceForFont(candidate);
        bool candidateCovers = face != NULL;
        for (size_t i = 0; candidateCovers && i < count; i++) {
            FT_UInt glyph = FT_Get_Char_Index(face, codePoints[i]);
            candidateCovers = glyph != 0 && glyph <= UINT16_MAX;
        }
        if (candidateCovers) {
            free(codePoints);
            return candidate;
        }
        CFRelease(candidate);
    }

    // Fontconfig supplies system defaults when no explicit language is given.
    O2FontRef substitute = O2FontCreateWithCodePointCoverage(codePoints, count,
            baseFace, language != NULL ? [(NSString *)language UTF8String] : NULL);
    free(codePoints);
    if (substitute == nil)
        return NULL;
    CTFontRef result = createFont((CGFontRef)substitute, CTFontGetSize(currentFont));
    O2FontRelease(substitute);
    return result;
}

CTFontDescriptorRef CTFontCopyFontDescriptor(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFTypeRef CTFontCopyAttribute(CTFontRef font, CFStringRef attribute)
{
    if (!font || !attribute) return nil;
    if (CFEqual(attribute, kCTFontCascadeListAttribute))
        return (CFTypeRef)[fontCascade(font) copy];
    if (CFEqual(attribute, kCTFontNameAttribute)) {
        return CTFontCopyName(font, kCTFontFullNameKey);
    }
    if (CFEqual(attribute, kCTFontFamilyNameAttribute)) {
        return CTFontCopyFamilyName(font);
    }
    if (CFEqual(attribute, kCTFontPostScriptNameAttribute) || CFEqual(attribute, kCTFontPostScriptNameKey)) {
        return CTFontCopyPostScriptName(font);
    }
    if (CFEqual(attribute, kCTFontSizeAttribute)) {
        CGFloat size = CTFontGetSize(font);
        return (CFTypeRef)[[NSNumber numberWithDouble:size] retain];
    }
    return nil;
}

CGFloat CTFontGetSize(CTFontRef self) {
    return fontSize(self);
}

CGAffineTransform CTFontGetMatrix(CTFontRef font)
{
    return CGAffineTransformIdentity;
}

CTFontSymbolicTraits CTFontGetSymbolicTraits(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return kCTFontTraitItalic;
}

CFDictionaryRef CTFontCopyTraits(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFArrayRef CTFontCopyDefaultCascadeListForLanguages(CTFontRef font, CFArrayRef languagePrefList)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFStringRef CTFontCopyPostScriptName(CTFontRef self)
{
    CGFontRef cgFont = graphicsFont(self);
    CFStringRef name = cgFont ? CGFontCopyPostScriptName(cgFont) : NULL;
    if (!name && cgFont)
        name = CGFontCopyFullName(cgFont);
    return name;
}

CFStringRef CTFontCopyFamilyName(CTFontRef self)
{
    if (self == NULL) return NULL;
    FT_Face face = faceForFont(self);
    if (face != NULL && face->family_name != NULL) {
        return CFStringCreateWithCString(kCFAllocatorDefault, face->family_name, kCFStringEncodingUTF8);
    }
    CGFontRef cgFont = graphicsFont(self);
    CFStringRef fullName = cgFont ? CGFontCopyFullName(cgFont) : NULL;
    if (fullName != NULL) {
        // Fallback: extract base family name if formatted as "Family-Style" (e.g. "Helvetica-Bold" -> "Helvetica")
        CFRange dashRange = CFStringFind(fullName, CFSTR("-"), 0);
        if (dashRange.location != kCFNotFound && dashRange.location > 0) {
            CFStringRef family = CFStringCreateWithSubstring(kCFAllocatorDefault, fullName, CFRangeMake(0, dashRange.location));
            CFRelease(fullName);
            return family;
        }
        return fullName;
    }
    return NULL;
}

CFStringRef CTFontCopyFullName(CTFontRef self) {
    return CGFontCopyFullName(graphicsFont(self));
}

CFStringRef CTFontCopyDisplayName(CTFontRef self)
{
    return CTFontCopyFullName(self);
}

CFStringRef _Nullable CTFontCopyName(CTFontRef font, CFStringRef nameKey)
{
    // CFEqual halts on a NULL argument; a missing key names nothing.
    if (nameKey == NULL)
        return NULL;
    if (CFEqual(nameKey, kCTFontPostScriptNameKey))
        return CTFontCopyPostScriptName(font);
    if (CFEqual(nameKey, kCTFontFamilyNameKey))
        return CTFontCopyFamilyName(font);
    return CTFontCopyFullName(font);
}

CFStringRef CTFontCopyLocalizedName(CTFontRef font, CFStringRef nameKey,
                                    CFStringRef  _Nullable *actualLanguage)
{
    // Only the canonical name is available and its language is unknown; callers
    // such as Chromium read *actualLanguage whenever it is non-NULL.
    if (actualLanguage) *actualLanguage = NULL;
    if (!font || !nameKey) return NULL;
    return CTFontCopyName(font, nameKey);
}

CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font)
{
    if (!font) return NULL;
    CGFontRef cgFont = graphicsFont(font);
    if (![(id)cgFont isKindOfClass:[O2Font_freetype class]]) return NULL;
    FT_Face face = [(O2Font_freetype *)cgFont face];
    if (!face || !face->charmap || face->charmap->encoding != FT_ENCODING_UNICODE)
        return NULL;
    NSCharacterSet *set = O2FontGetCoveredCharacterSet((O2FontRef)cgFont);
    return set ? CFCharacterSetCreateCopy(kCFAllocatorDefault, (CFCharacterSetRef)set) : NULL;
}

CFStringEncoding CTFontGetStringEncoding(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return CFStringGetSystemEncoding();
}

CFArrayRef CTFontCopySupportedLanguages(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CGFloat CTFontGetAscent(CTFontRef self) {
    return scaled(self, CGFontGetAscent(graphicsFont(self)));
}

// CoreGraphics reports the descent as negative, CoreText as positive.
CGFloat CTFontGetDescent(CTFontRef self) {
    return -scaled(self, CGFontGetDescent(graphicsFont(self)));
}

CGFloat CTFontGetLeading(CTFontRef self) {
    return scaled(self, CGFontGetLeading(graphicsFont(self)));
}

unsigned int CTFontGetUnitsPerEm(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return 0;
}

CFIndex CTFontGetGlyphCount(CTFontRef font) {
    return CGFontGetNumberOfGlyphs(graphicsFont(font));
}

CGRect CTFontGetBoundingBox(CTFontRef self) {
    CGRect box = CGFontGetFontBBox(graphicsFont(self));
    return CGRectMake(scaled(self, box.origin.x), scaled(self, box.origin.y),
                      scaled(self, box.size.width), scaled(self, box.size.height));
}

CGFloat CTFontGetUnderlinePosition(CTFontRef self) {
    return scaled(self, faceForFont(self)->underline_position);
}

CGFloat CTFontGetUnderlineThickness(CTFontRef self) {
    return scaled(self, faceForFont(self)->underline_thickness);
}

CGFloat CTFontGetSlantAngle(CTFontRef self) {
    return CGFontGetItalicAngle(graphicsFont(self));
}

CGFloat CTFontGetCapHeight(CTFontRef self) {
    return scaled(self, CGFontGetCapHeight(graphicsFont(self)));
}

CGFloat CTFontGetXHeight(CTFontRef self) {
    return scaled(self, CGFontGetXHeight(graphicsFont(self)));
}

typedef struct {
    CGMutablePathRef path;
    const CGAffineTransform *matrix;
    BOOL contourOpen;
} GlyphPathBuilder;

static int glyphPathMoveTo(const FT_Vector *to, void *user) {
    GlyphPathBuilder *builder = user;

    if (builder->contourOpen)
        CGPathCloseSubpath(builder->path);
    CGPathMoveToPoint(builder->path, builder->matrix, to->x, to->y);
    builder->contourOpen = YES;
    return 0;
}

static int glyphPathLineTo(const FT_Vector *to, void *user) {
    GlyphPathBuilder *builder = user;

    CGPathAddLineToPoint(builder->path, builder->matrix, to->x, to->y);
    return 0;
}

static int glyphPathConicTo(const FT_Vector *control, const FT_Vector *to, void *user) {
    GlyphPathBuilder *builder = user;

    CGPathAddQuadCurveToPoint(builder->path, builder->matrix, control->x, control->y,
                              to->x, to->y);
    return 0;
}

static int glyphPathCubicTo(const FT_Vector *control1, const FT_Vector *control2,
                            const FT_Vector *to, void *user)
{
    GlyphPathBuilder *builder = user;

    CGPathAddCurveToPoint(builder->path, builder->matrix, control1->x, control1->y,
                          control2->x, control2->y, to->x, to->y);
    return 0;
}

CGPathRef CTFontCreatePathForGlyph(CTFontRef self, CGGlyph glyph,
                                   CGAffineTransform *xform)
{
    FT_Face face = faceForFont(self);

    // Unscaled outlines are in font units, so the shared face's size is left alone.
    if (FT_Load_Glyph(face, glyph, FT_LOAD_NO_SCALE) != 0 ||
        face->glyph->format != FT_GLYPH_FORMAT_OUTLINE)
        return NULL;

    CGFloat unit = scaled(self, 1);
    CGAffineTransform matrix = CGAffineTransformMakeScale(unit, unit);
    if (xform != NULL)
        matrix = CGAffineTransformConcat(matrix, *xform);

    GlyphPathBuilder builder = {CGPathCreateMutable(), &matrix, NO};
    const FT_Outline_Funcs funcs = {glyphPathMoveTo, glyphPathLineTo, glyphPathConicTo,
                                    glyphPathCubicTo, 0, 0};

    if (FT_Outline_Decompose(&face->glyph->outline, &funcs, &builder) != 0) {
        CGPathRelease(builder.path);
        return NULL;
    }
    if (builder.contourOpen)
        CGPathCloseSubpath(builder.path);
    return builder.path;
}

CFStringRef CTFontCopyNameForGlyph(CTFontRef font, CGGlyph glyph)
{
    if (!font) return NULL;
    CGFontRef cgFont = graphicsFont(font);
    if (![(id)cgFont isKindOfClass:[O2Font_freetype class]] ||
        glyph >= CGFontGetNumberOfGlyphs(cgFont))
        return NULL;
    return CGFontCopyGlyphNameForGlyph(cgFont, glyph);
}

CGGlyph CTFontGetGlyphWithName(CTFontRef font, CFStringRef glyphName)
{
    if (!font || !glyphName) return CGNullGlyph;
    CGFontRef cgFont = graphicsFont(font);
    return cgFont ? CGFontGetGlyphWithGlyphName(cgFont, glyphName) : CGNullGlyph;
}

CGRect CTFontGetBoundingRectsForGlyphs(CTFontRef font, CTFontOrientation orientation,
                                       const CGGlyph *glyphs, CGRect *boundingRects,
                                       CFIndex count)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return CGRectMake(0, 0, 0, 0);
}

double CTFontGetAdvancesForGlyphs(CTFontRef font, CTFontOrientation orientation,
                                const CGGlyph *glyphs, CGSize *advances,
                                CFIndex count)
{
    FT_Face face = faceForFont(font);
    FT_Set_Pixel_Sizes(face, fontSize(font), fontSize(font));

    double sum = 0;
    for (CFIndex i = 0; i < count; i++) {
        FT_Load_Glyph(face, glyphs[i], FT_LOAD_DEFAULT);
        CGSize advance = CGSizeMake(face->glyph->advance.x / 64.0, face->glyph->advance.y / 64.0);
        if (advances != NULL)
            advances[i] = advance;
        sum += advance.width;
    }
    return sum;
}

CGRect CTFontGetOpticalBoundsForGlyphs(CTFontRef font, const CGGlyph *glyphs,
                                       CGRect *boundingRects, CFIndex count,
                                       CFOptionFlags options)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return CGRectMake(0, 0, 0, 0);
}

void CTFontGetVerticalTranslationsForGlyphs(CTFontRef font, const CGGlyph *glyphs,
                                            CGSize *translations, CFIndex count)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
}

CFArrayRef CTFontCopyVariationAxes(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFDictionaryRef CTFontCopyVariation(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFArrayRef CTFontCopyFeatures(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFArrayRef CTFontCopyFeatureSettings(CTFontRef font)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

bool CTFontGetGlyphsForCharacters(CTFontRef font, const UniChar *characters,
                                  CGGlyph *glyphs, CFIndex count)
{
    if (count < 0)
        return false;
    if (count == 0)
        return true;
    if (font == NULL || characters == NULL || glyphs == NULL)
        return false;

    FT_Face face = faceForFont(font);
    bool convertedAll = true;
    for (CFIndex i = 0; i < count; i++) {
        uint32_t codePoint = characters[i];
        bool paired = codePoint >= 0xD800 && codePoint <= 0xDBFF &&
                i + 1 < count && characters[i + 1] >= 0xDC00 &&
                characters[i + 1] <= 0xDFFF;
        if (paired)
            codePoint = 0x10000 + ((codePoint - 0xD800) << 10) +
                    (characters[i + 1] - 0xDC00);

        // Unpaired surrogates are not Unicode scalar values.
        FT_UInt glyph = face != NULL &&
                !(codePoint >= 0xD800 && codePoint <= 0xDFFF)
                ? FT_Get_Char_Index(face, codePoint) : 0;
        glyphs[i] = glyph <= UINT16_MAX ? (CGGlyph)glyph : 0;
        if (glyphs[i] == 0)
            convertedAll = false;
        // Preserve UTF-16 indexing: the low surrogate has no separate glyph.
        if (paired)
            glyphs[++i] = 0;
    }
    return convertedAll;
}

void CTFontDrawGlyphs(CTFontRef font, const CGGlyph *glyphs, const CGPoint *positions,
                      size_t count, CGContextRef context)
{
    if (font == NULL || glyphs == NULL || positions == NULL || count == 0 ||
        context == NULL)
        return;

    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (graphicsFont == NULL)
        return;
    CGContextSetFont(context, graphicsFont);
    CGContextSetFontSize(context, CTFontGetSize(font));
    CGContextShowGlyphsAtPositions(context, glyphs, positions, count);
    CGFontRelease(graphicsFont);
}

void CTFontDrawGlyphsWithAdvances(CTFontRef font, const CGGlyph *glyphs,
                                  const CGSize *advances, size_t count,
                                  CGContextRef context)
{
    CGFontRef cgFont = graphicsFont(font);
    if (cgFont == NULL || context == NULL || count == 0)
        return;
    CGContextSetFont(context, cgFont);
    CGContextSetFontSize(context, CTFontGetSize(font));
    CGContextShowGlyphsWithAdvances(context, glyphs, advances, count);
}

bool CTFontShouldAntiAlias(CTFontRef font)
{
    return true;
}

CFIndex CTFontGetLigatureCaretPositions(CTFontRef font, CGGlyph glyph, CGFloat *positions,
                                        CFIndex maxPositions)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return -1;
}

CGFontRef CTFontCopyGraphicsFont(CTFontRef font, CTFontDescriptorRef _Nullable *attributes)
{
    if (attributes) *attributes = NULL;
    if (!font) return NULL;
    CGFontRef cgFont = graphicsFont(font);
    return cgFont ? CGFontRetain(cgFont) : NULL;
}

CTFontRef
CTFontCreateWithGraphicsFont(CGFontRef cgFont, CGFloat size,
                             CGAffineTransform *xform,
                             CTFontDescriptorRef attributes)
{
    CTFontRef result = createFont(cgFont, size);
    setFontCascade(result, [(NSDictionary *)attributes objectForKey:(id)kCTFontCascadeListAttribute]);
    return result;
}

ATSFontRef CTFontGetPlatformFont(CTFontRef font, CTFontDescriptorRef  _Nullable *attributes)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return 0;
}

CTFontRef CTFontCreateWithPlatformFont(ATSFontRef platformFont, CGFloat size,
                                       const CGAffineTransform *matrix,
                                       CTFontDescriptorRef attributes)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CTFontRef CTFontCreateWithQuickdrawInstance(ConstStr255Param name, int16_t identifier,
                                            uint8_t style, CGFloat size)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFArrayRef CTFontCopyAvailableTables(CTFontRef font, CTFontTableOptions options)
{
    if (!font || (options & ~kCTFontTableOptionExcludeSynthetic)) return nil;
    CGFontRef cgFont = graphicsFont(font);
    if (!cgFont) return nil;
    return CGFontCopyTableTags(cgFont);
}

CFDataRef CTFontCopyTable(CTFontRef font, CTFontTableTag table, CTFontTableOptions options)
{
    if (!font || (options & ~kCTFontTableOptionExcludeSynthetic)) return nil;
    CGFontRef cgFont = graphicsFont(font);
    if (!cgFont) return nil;
    return CGFontCopyTableForTag(cgFont, (uint32_t)table);
}

CFTypeID CTFontGetTypeID(void)
{
    return (CFTypeID)[KTFont self];
}

uint32_t CTGetCoreTextVersion(void)
{
    return 0x000C0000;
}
