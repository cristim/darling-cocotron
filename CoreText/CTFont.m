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
#import <CoreText/CTFontDescriptor.h>
#import <CoreGraphics/CGDataProvider.h>
#import <CoreGraphics/CGFont.h>
#import <Onyx2D/O2Font.h>

/* NSFont uses 32-bit NSGlyph buffers; CTFont uses 16-bit CGGlyph buffers.
 * Bridge to the underlying KTFont before calling font methods. */
static CTFontRef normalizedFont(CTFontRef font) {
    if (font && [(id)font respondsToSelector:@selector(_coreTextFont)])
        return (CTFontRef)[(id)font performSelector:@selector(_coreTextFont)];
    return font;
}

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

CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix)
{
    if (!name)
        return nil;
    CGFontRef cgFont = CGFontCreateWithFontName(name);
    if (!cgFont)
        return nil;
    if (size == 0)
        size = 12;
    KTFont *font = [[KTFont alloc] initWithFont:cgFont size:size];
    CGFontRelease(cgFont);
    (void)matrix;
    return (CTFontRef)font;
}

CTFontRef CTFontCreateWithNameAndOptions(CFStringRef name, CGFloat size,
                                         const CGAffineTransform *matrix,
                                         CTFontOptions options)
{
    (void)options;
    return CTFontCreateWithName(name, size, matrix);
}

CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef descriptor, CGFloat size,
                                         const CGAffineTransform *matrix)
{
    if (!descriptor)
        return nil;
    if (size == 0) {
        CFTypeRef descriptorSize = CTFontDescriptorCopyAttribute(descriptor, kCTFontSizeAttribute);
        if (descriptorSize) {
            if (CFGetTypeID(descriptorSize) == CFNumberGetTypeID())
                CFNumberGetValue((CFNumberRef)descriptorSize, kCFNumberCGFloatType, &size);
            CFRelease(descriptorSize);
        }
        if (size == 0)
            size = 12;
    }
    /* Darling path: descriptors built by CTFontManagerCreateFontDescriptorFromData
     * carry the raw font bytes; feed them to FreeType via O2Font. */
    CFTypeRef dataObj = CTFontDescriptorCopyAttribute(descriptor, CFSTR("DarlingFontData"));
    if (dataObj) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)dataObj);
        CFRelease(dataObj);
        if (provider) {
            CGFontRef cgFont = CGFontCreateWithDataProvider(provider);
            CGDataProviderRelease(provider);
            if (cgFont) {
                KTFont *font = [[KTFont alloc] initWithFont:cgFont size:size];
                CGFontRelease(cgFont);
                (void)matrix;
                return (CTFontRef)font;
            }
        }
    }
    CFStringRef name = (CFStringRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
    if (!name)
        name = (CFStringRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute);
    if (!name)
        return nil;
    CTFontRef result = CTFontCreateWithName(name, size, matrix);
    CFRelease(name);
    return result;
}

CTFontRef CTFontCreateWithFontDescriptorAndOptions(CTFontDescriptorRef descriptor, CGFloat size,
                                                   const CGAffineTransform *matrix,
                                                   CTFontOptions options)
{
    (void)options;
    return CTFontCreateWithFontDescriptor(descriptor, size, matrix);
}

CTFontRef CTFontCreateUIFontForLanguage(CTFontUIFontType uiFontType,
                                        CGFloat size, CFStringRef language)
{
    return (CTFontRef)[[KTFont alloc] initWithUIFontType: uiFontType
                                         size: size
                                     language: (NSString*)language];
}

CTFontRef CTFontCreateCopyWithAttributes(CTFontRef font, CGFloat size,
                                         const CGAffineTransform *matrix,
                                         CTFontDescriptorRef attributes)
{
    font = normalizedFont(font);
    if (!font)
        return nil;
    if (attributes) {
        CFTypeRef name = CTFontDescriptorCopyAttribute(attributes, kCTFontNameAttribute);
        if (name) {
            CTFontRef result = CTFontCreateWithName((CFStringRef)name, size, matrix);
            CFRelease(name);
            if (result)
                return result;
        }
    }
    CGFontRef cgFont = [(KTFont *)font copyGraphicsFont];
    if (!cgFont)
        return nil;
    if (size == 0)
        size = [(KTFont *)font pointSize];
    CTFontRef result = (CTFontRef)[[KTFont alloc] initWithFont:cgFont size:size];
    CGFontRelease(cgFont);
    (void)matrix;
    return result;
}

CTFontRef CTFontCreateCopyWithSymbolicTraits(CTFontRef font, CGFloat size,
                                             const CGAffineTransform *matrix,
                                             CTFontSymbolicTraits symTraitValue, 
                                             CTFontSymbolicTraits symTraitMask)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CTFontRef CTFontCreateCopyWithFamily(CTFontRef font, CGFloat size,
                                     const CGAffineTransform *matrix, CFStringRef family)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CTFontRef CTFontCreateForString(CTFontRef currentFont, CFStringRef string, CFRange range)
{
    currentFont = normalizedFont(currentFont);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CTFontRef CTFontCreateForStringWithLanguage(CTFontRef currentFont, CFStringRef string,
                                            CFRange range, CFStringRef language)
{
    currentFont = normalizedFont(currentFont);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CTFontDescriptorRef CTFontCopyFontDescriptor(CTFontRef font)
{
    font = normalizedFont(font);
    if (!font)
        return nil;
    CFStringRef name = CTFontCopyPostScriptName(font);
    CFDictionaryRef traits = CTFontCopyTraits(font);
    CGFloat size = CTFontGetSize(font);
    CFNumberRef sizeValue = CFNumberCreate(NULL, kCFNumberCGFloatType, &size);
    if (!name || !traits || !sizeValue) {
        if (name) CFRelease(name);
        if (traits) CFRelease(traits);
        if (sizeValue) CFRelease(sizeValue);
        return nil;
    }
    const void *keys[] = {kCTFontNameAttribute, kCTFontSizeAttribute, kCTFontTraitsAttribute};
    const void *values[] = {name, sizeValue, traits};
    CFDictionaryRef attributes = CFDictionaryCreate(NULL, keys, values, 3,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CTFontDescriptorRef result = CTFontDescriptorCreateWithAttributes(attributes);
    CFRelease(attributes);
    CFRelease(name);
    CFRelease(sizeValue);
    CFRelease(traits);
    return result;
}

CFTypeRef CTFontCopyAttribute(CTFontRef font, CFStringRef attribute)
{
    font = normalizedFont(font);
    CTFontDescriptorRef descriptor = CTFontCopyFontDescriptor(font);
    if (!descriptor)
        return nil;
    CFTypeRef value = CTFontDescriptorCopyAttribute(descriptor, attribute);
    CFRelease(descriptor);
    return value;
}

CGFloat CTFontGetSize(CTFontRef self) {
    self = normalizedFont(self);
    return [self pointSize];
}

CGAffineTransform CTFontGetMatrix(CTFontRef font)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return CGAffineTransformIdentity;
}

static CTFontSymbolicTraits fontTraits(CTFontRef font, CGFloat *weight, CGFloat *width)
{
    static const CGFloat weights[] = {-0.8, -0.6, -0.4, 0, 0.23, 0.3, 0.4, 0.56, 0.62};
    unsigned int weightClass = 400, widthClass = 5;
    CTFontSymbolicTraits traits = 0;
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (graphicsFont) {
        CFDataRef table = CGFontCopyTableForTag(graphicsFont, 0x4f532f32 /* OS/2 */);
        if (table && CFDataGetLength(table) >= 8) {
            const UInt8 *bytes = CFDataGetBytePtr(table);
            weightClass = ((unsigned int)bytes[4] << 8) | bytes[5];
            widthClass = ((unsigned int)bytes[6] << 8) | bytes[7];
        }
        if (table) CFRelease(table);
        table = CGFontCopyTableForTag(graphicsFont, 0x706f7374 /* post */);
        if (table && CFDataGetLength(table) >= 16) {
            const UInt8 *bytes = CFDataGetBytePtr(table);
            if (bytes[12] || bytes[13] || bytes[14] || bytes[15])
                traits |= kCTFontTraitMonoSpace;
        }
        if (table) CFRelease(table);
        if (CGFontGetItalicAngle(graphicsFont) != 0)
            traits |= kCTFontTraitItalic;
        CGFontRelease(graphicsFont);
    }
    if (weightClass < 100) weightClass = 100;
    if (weightClass > 900) weightClass = 900;
    unsigned int index = weightClass / 100 - 1;
    *weight = weights[index];
    if (index < 8)
        *weight += (weights[index + 1] - weights[index]) * (weightClass % 100) / 100.0;
    if (widthClass < 1 || widthClass > 9) widthClass = 5;
    *width = ((CGFloat)widthClass - 5) / 4;
    if (weightClass >= 700) traits |= kCTFontTraitBold;
    if (widthClass < 5) traits |= kCTFontTraitCondensed;
    if (widthClass > 5) traits |= kCTFontTraitExpanded;
    return traits;
}

CTFontSymbolicTraits CTFontGetSymbolicTraits(CTFontRef font)
{
    font = normalizedFont(font);
    CGFloat weight, width;
    return font ? fontTraits(font, &weight, &width) : 0;
}

CFDictionaryRef CTFontCopyTraits(CTFontRef font)
{
    font = normalizedFont(font);
    if (!font) return nil;
    CGFloat weight, width, slant = 0;
    SInt32 symbolic = fontTraits(font, &weight, &width);
    if (symbolic & kCTFontTraitItalic) slant = 0.2;
    const void *keys[] = {kCTFontSymbolicTrait, kCTFontWeightTrait, kCTFontWidthTrait, kCTFontSlantTrait};
    CFNumberRef values[] = {
        CFNumberCreate(NULL, kCFNumberSInt32Type, &symbolic),
        CFNumberCreate(NULL, kCFNumberCGFloatType, &weight),
        CFNumberCreate(NULL, kCFNumberCGFloatType, &width),
        CFNumberCreate(NULL, kCFNumberCGFloatType, &slant)
    };
    CFDictionaryRef result = CFDictionaryCreate(NULL, keys, (const void **)values, 4,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    for (int i = 0; i < 4; ++i) CFRelease(values[i]);
    return result;
}

CFArrayRef CTFontCopyDefaultCascadeListForLanguages(CTFontRef font, CFArrayRef languagePrefList)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFStringRef CTFontCopyPostScriptName(CTFontRef font)
{
    font = normalizedFont(font);
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (!graphicsFont) return nil;
    CFStringRef name = CGFontCopyPostScriptName(graphicsFont);
    CGFontRelease(graphicsFont);
    return name;
}

CFStringRef CTFontCopyFamilyName(CTFontRef font)
{
    font = normalizedFont(font);
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (!graphicsFont) return nil;
    CFStringRef name = (CFStringRef)[(O2Font *)graphicsFont copyFamilyName];
    CGFontRelease(graphicsFont);
    return name;
}

CFStringRef CTFontCopyFullName(CTFontRef self) {
    self = normalizedFont(self);
    return [self copyName];
}

CFStringRef CTFontCopyDisplayName(CTFontRef font)
{
    font = normalizedFont(font);
    return CTFontCopyFullName(font);
}

CFStringRef _Nullable CTFontCopyName(CTFontRef font, CFStringRef nameKey)
{
    font = normalizedFont(font);
    if (!font || !nameKey) return nil;
    if (CFEqual(nameKey, kCTFontPostScriptNameKey)) return CTFontCopyPostScriptName(font);
    if (CFEqual(nameKey, kCTFontFamilyNameKey)) return CTFontCopyFamilyName(font);
    if (CFEqual(nameKey, kCTFontFullNameKey)) return CTFontCopyFullName(font);
    return nil;
}

CFStringRef CTFontCopyLocalizedName(CTFontRef font, CFStringRef nameKey,
                                    CFStringRef  _Nullable *actualLanguage)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFStringEncoding CTFontGetStringEncoding(CTFontRef font)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return CFStringGetSystemEncoding();
}

CFArrayRef CTFontCopySupportedLanguages(CTFontRef font)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CGFloat CTFontGetAscent(CTFontRef self) {
    self = normalizedFont(self);
    return [self ascender];
}

CGFloat CTFontGetDescent(CTFontRef self) {
    self = normalizedFont(self);
    return [self descender];
}

CGFloat CTFontGetLeading(CTFontRef self) {
    self = normalizedFont(self);
    return [self leading];
}

unsigned int CTFontGetUnitsPerEm(CTFontRef font)
{
    font = normalizedFont(font);
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (!graphicsFont)
        return 0;
    unsigned int units = CGFontGetUnitsPerEm(graphicsFont);
    CGFontRelease(graphicsFont);
    return units;
}

CFIndex CTFontGetGlyphCount(CTFontRef font) {
    font = normalizedFont(font);
    return [font numberOfGlyphs];
}

CGRect CTFontGetBoundingBox(CTFontRef self) {
    self = normalizedFont(self);
    return [self boundingRect];
}

CGFloat CTFontGetUnderlinePosition(CTFontRef self) {
    self = normalizedFont(self);
    return [self underlinePosition];
}

CGFloat CTFontGetUnderlineThickness(CTFontRef self) {
    self = normalizedFont(self);
    return [self underlineThickness];
}

CGFloat CTFontGetSlantAngle(CTFontRef self) {
    self = normalizedFont(self);
    return [self italicAngle];
}

CGFloat CTFontGetCapHeight(CTFontRef self) {
    self = normalizedFont(self);
    return [self capHeight];
}

CGFloat CTFontGetXHeight(CTFontRef self) {
    self = normalizedFont(self);
    return [self xHeight];
}

CGPathRef CTFontCreatePathForGlyph(CTFontRef self, CGGlyph glyph,
                                   CGAffineTransform *xform)
{
    self = normalizedFont(self);
    return (CGPathRef) [self createPathForGlyph: glyph transform: xform];
}

CGGlyph CTFontGetGlyphWithName(CTFontRef font, CFStringRef glyphName)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return CGNullGlyph;
}

CGRect CTFontGetBoundingRectsForGlyphs(CTFontRef font, CTFontOrientation orientation,
                                       const CGGlyph *glyphs, CGRect *boundingRects,
                                       CFIndex count)
{
    font = normalizedFont(font);
    if (!font || !glyphs || count <= 0)
        return CGRectZero;
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (!graphicsFont)
        return CGRectZero;
    int units = CGFontGetUnitsPerEm(graphicsFont);
    CGFloat scale = units > 0 ? CTFontGetSize(font) / units : 0;
    CGRect total = CGRectNull;
    for (CFIndex i = 0; i < count; ++i) {
        O2Rect bounds = [(O2Font *)graphicsFont boundingRectForGlyph:glyphs[i]];
        CGRect rect = CGRectMake(bounds.origin.x * scale, bounds.origin.y * scale,
                bounds.size.width * scale, bounds.size.height * scale);
        if (boundingRects) boundingRects[i] = rect;
        total = CGRectUnion(total, rect);
    }
    CGFontRelease(graphicsFont);
    return total;
}

double CTFontGetAdvancesForGlyphs(CTFontRef font, CTFontOrientation orientation,
                                const CGGlyph *glyphs, CGSize *advances,
                                CFIndex count)
{
    font = normalizedFont(font);
    if (!font || !glyphs || count <= 0)
        return 0;
    if (advances)
        [(KTFont *)font getAdvancements: advances forGlyphs: glyphs count: count];
    double sum = 0;

    for (CFIndex i = 0; i < count; i++) {
        CGSize advance;
        if (advances)
            advance = advances[i];
        else
            [(KTFont *)font getAdvancements: &advance forGlyphs: &glyphs[i] count: 1];
        sum += advance.width;
    }

    return sum;
}

CGRect CTFontGetOpticalBoundsForGlyphs(CTFontRef font, const CGGlyph *glyphs,
                                       CGRect *boundingRects, CFIndex count,
                                       CFOptionFlags options)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return CGRectMake(0, 0, 0, 0);
}

void CTFontGetVerticalTranslationsForGlyphs(CTFontRef font, const CGGlyph *glyphs,
                                            CGSize *translations, CFIndex count)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
}

CFArrayRef CTFontCopyVariationAxes(CTFontRef font)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFDictionaryRef CTFontCopyVariation(CTFontRef font)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFArrayRef CTFontCopyFeatures(CTFontRef font)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFArrayRef CTFontCopyFeatureSettings(CTFontRef font)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

bool CTFontGetGlyphsForCharacters(CTFontRef font, const UniChar *characters,
                                  CGGlyph *glyphs, CFIndex count)
{
    font = normalizedFont(font);
    [font getGlyphs: glyphs forCharacters: characters length: count];
    // FIXME: change getGlyphs: to return a BOOL
    return YES;
}

void CTFontDrawGlyphs(CTFontRef font, const CGGlyph *glyphs, const CGPoint *positions,
                      size_t count, CGContextRef context)
{
    font = normalizedFont(font);
    if (!font || !context || !glyphs || !positions || !count)
        return;
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (!graphicsFont)
        return;
    CGContextSaveGState(context);
    CGContextSetFont(context, graphicsFont);
    CGContextSetFontSize(context, CTFontGetSize(font));
    CGContextShowGlyphsAtPositions(context, glyphs, positions, count);
    CGContextRestoreGState(context);
    CGFontRelease(graphicsFont);
}

CFIndex CTFontGetLigatureCaretPositions(CTFontRef font, CGGlyph glyph, CGFloat *positions,
                                        CFIndex maxPositions)
{
    font = normalizedFont(font);
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return -1;
}

CGFontRef CTFontCopyGraphicsFont(CTFontRef font, CTFontDescriptorRef _Nullable *attributes)
{
    font = normalizedFont(font);
    if (attributes)
        *attributes = nil;
    if (!font)
        return nil;
    return [(KTFont *)font copyGraphicsFont];
}

CTFontRef
CTFontCreateWithGraphicsFont(CGFontRef cgFont, CGFloat size,
                             CGAffineTransform *xform,
                             CTFontDescriptorRef attributes)
{
    return (CTFontRef)[[KTFont alloc] initWithFont: cgFont size: size];
}

ATSFontRef CTFontGetPlatformFont(CTFontRef font, CTFontDescriptorRef  _Nullable *attributes)
{
    font = normalizedFont(font);
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
    font = normalizedFont(font);
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (!graphicsFont)
        return nil;
    CFArrayRef result = (CFArrayRef)[(O2Font *)graphicsFont copyTableTags];
    CGFontRelease(graphicsFont);
    (void)options;
    return result;
}

CFDataRef CTFontCopyTable(CTFontRef font, CTFontTableTag table, CTFontTableOptions options)
{
    font = normalizedFont(font);
    if (!font)
        return nil;
    CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
    if (!graphicsFont)
        return nil;
    CFDataRef data = CGFontCopyTableForTag(graphicsFont, table);
    CGFontRelease(graphicsFont);
    return data;
}

CFTypeID CTFontGetTypeID(void)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return 0;
}
