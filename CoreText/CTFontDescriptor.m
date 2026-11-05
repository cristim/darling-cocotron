#import <CoreText/CTFontDescriptor.h>
#import <CoreText/CTFont.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Onyx2D/O2Font_freetype.h>

#include <stdio.h>

const CFStringRef kCTFontURLAttribute = CFSTR("NSCTFontFileURLAttribute");
const CFStringRef kCTFontNameAttribute = CFSTR("NSFontNameAttribute");
const CFStringRef kCTFontDisplayNameAttribute = CFSTR("NSFontVisibleNameAttribute");
const CFStringRef kCTFontFamilyNameAttribute = CFSTR("NSFontFamilyAttribute");
const CFStringRef kCTFontStyleNameAttribute = CFSTR("NSFontFaceAttribute");
const CFStringRef kCTFontPostScriptNameAttribute = CFSTR("NSFontPostScriptNameAttribute");
const CFStringRef kCTFontTraitsAttribute = CFSTR("NSCTFontTraitsAttribute");
const CFStringRef kCTFontVariationAttribute = CFSTR("NSCTFontVariationAttribute");
const CFStringRef kCTFontVariationAxesAttribute = CFSTR("NSCTFontVariationAxesAttribute");
const CFStringRef kCTFontSizeAttribute = CFSTR("NSFontSizeAttribute");
const CFStringRef kCTFontMatrixAttribute = CFSTR("NSCTFontMatrixAttribute");
const CFStringRef kCTFontCascadeListAttribute = CFSTR("NSCTFontCascadeListAttribute");
const CFStringRef kCTFontCharacterSetAttribute = CFSTR("NSCTFontCharacterSetAttribute");
const CFStringRef kCTFontLanguagesAttribute = CFSTR("NSCTFontLanguagesAttribute");
const CFStringRef kCTFontBaselineAdjustAttribute = CFSTR("NSCTFontBaselineAdjustAttribute");
const CFStringRef kCTFontMacintoshEncodingsAttribute = CFSTR("NSCTFontMacintoshEncodingsAttribute");
const CFStringRef kCTFontFeaturesAttribute = CFSTR("NSCTFontFeaturesAttribute");
const CFStringRef kCTFontFeatureSettingsAttribute = CFSTR("NSCTFontFeatureSettingsAttribute");
const CFStringRef kCTFontFixedAdvanceAttribute = CFSTR("NSCTFontFixedAdvanceAttribute");
const CFStringRef kCTFontOrientationAttribute = CFSTR("NSCTFontOrientationAttribute");
const CFStringRef kCTFontEnabledAttribute = CFSTR("NSCTFontEnabledAttribute");
const CFStringRef kCTFontFormatAttribute = CFSTR("NSCTFontFormatAttribute");
const CFStringRef kCTFontRegistrationScopeAttribute = CFSTR("NSCTFontRegistrationScopeAttribute");
const CFStringRef kCTFontPriorityAttribute = CFSTR("NSCTFontPriorityAttribute");
const CFStringRef kCTFontDescriptorLanguageAttribute = CFSTR("CocotronFontDescriptorLanguageAttribute");

CFTypeID CTFontDescriptorGetTypeID(void)
{
    return CFDictionaryGetTypeID();
}

CTFontDescriptorRef CTFontDescriptorCreateWithAttributes(CFDictionaryRef attributes)
{
    if (!attributes) {
        return (CTFontDescriptorRef)[[NSDictionary dictionary] retain];
    }
    return (CTFontDescriptorRef)[(id)attributes copy];
}

CTFontDescriptorRef CTFontDescriptorCreateWithNameAndSize(CFStringRef name, CGFloat size)
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (name) {
        attributes[(id)kCTFontNameAttribute] = (id)name;
    }
    if (size > 0.0) {
        attributes[(id)kCTFontSizeAttribute] = [NSNumber numberWithDouble:(double)size];
    }
    return CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attributes);
}

CFDictionaryRef CTFontDescriptorCopyAttributes(CTFontDescriptorRef descriptor)
{
    if (!descriptor) return NULL;
    return (CFDictionaryRef)[(id)descriptor copy];
}

CFTypeRef CTFontDescriptorCopyAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute)
{
    if (!descriptor || !attribute) return nil;
    id val = [(NSDictionary *)descriptor objectForKey:(id)attribute];
    return (CFTypeRef)[val retain];
}

CFTypeRef CTFontDescriptorCopyLocalizedAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute,
                                                 CFStringRef *language)
{
    // Only the canonical value is known; its language is not.
    if (language)
        *language = NULL;
    return CTFontDescriptorCopyAttribute(descriptor, attribute);
}

// Descriptor name attributes and the fontconfig property each one matches.
static const struct {
    const CFStringRef *attribute;
    const char *property;
} matchedNames[] = {
    { &kCTFontFamilyNameAttribute, FC_FAMILY },
    { &kCTFontNameAttribute, FC_POSTSCRIPT_NAME },
    { &kCTFontPostScriptNameAttribute, FC_POSTSCRIPT_NAME },
    { &kCTFontStyleNameAttribute, FC_STYLE },
    { &kCTFontDisplayNameAttribute, FC_FULLNAME },
};

// The installed faces whose names match the descriptor's, as descriptors.
// FcFontList, unlike FcFontMatch, never substitutes another family for a
// missing one, so a family that is not installed matches nothing.
CFArrayRef CTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes)
{
    if (!descriptor) return (CFArrayRef)[[NSArray array] retain];
    NSDictionary *query = (NSDictionary *)descriptor;
    const size_t count = sizeof(matchedNames) / sizeof(matchedNames[0]);

    FcPattern *pattern = FcPatternCreate();
    // Not the variadic FcObjectSetBuild(): fontconfig is a native library and
    // arm64 Darwin and Linux pass variadic arguments differently.
    FcObjectSet *properties = FcObjectSetCreate();
    for (size_t i = 0; i < count; i++) {
        id value = [query objectForKey:(id)*matchedNames[i].attribute];
        if ([value isKindOfClass:[NSString class]])
            FcPatternAddString(pattern, matchedNames[i].property, (const FcChar8 *)[value UTF8String]);
        FcObjectSetAdd(properties, matchedNames[i].property);
    }
    FcObjectSetAdd(properties, FC_FILE);

    FcFontSet *fonts = FcFontList(O2FontSharedFontConfig(), pattern, properties);
    NSMutableArray *result = [NSMutableArray array];
    id size = [query objectForKey:(id)kCTFontSizeAttribute];
    for (int i = 0; fonts != NULL && i < fonts->nfont; i++) {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        FcChar8 *text;
        for (size_t j = 0; j < count; j++) {
            if (FcPatternGetString(fonts->fonts[i], matchedNames[j].property, 0, &text) == FcResultMatch) {
                NSString *value = [NSString stringWithUTF8String:(const char *)text];
                if (value)
                    [attributes setObject:value forKey:(id)*matchedNames[j].attribute];
            }
        }
        if (FcPatternGetString(fonts->fonts[i], FC_FILE, 0, &text) == FcResultMatch) {
            NSString *path = [NSString stringWithUTF8String:(const char *)text];
            if (path)
                [attributes setObject:[NSURL fileURLWithPath:path] forKey:(id)kCTFontURLAttribute];
        }
        // The point size is part of the request, not of the installed face.
        if (size)
            [attributes setObject:size forKey:(id)kCTFontSizeAttribute];

        BOOL matches = YES;
        for (id key in (NSSet *)mandatoryAttributes) {
            id expected = [query objectForKey:key];
            if (expected == nil || ![expected isEqual:[attributes objectForKey:key]]) {
                matches = NO;
                break;
            }
        }
        if (matches) {
            CTFontDescriptorRef match = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attributes);
            [result addObject:(id)match];
            CFRelease(match);
        }
    }
    if (fonts)
        FcFontSetDestroy(fonts);
    FcObjectSetDestroy(properties);
    FcPatternDestroy(pattern);
    return (CFArrayRef)[result retain];
}

CTFontDescriptorRef CTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes)
{
    if (!descriptor) return NULL;
    NSArray *matches = (NSArray *)CTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatoryAttributes);
    id result = [matches count] ? [[matches objectAtIndex:0] retain] : nil;
    [matches release];
    return (CTFontDescriptorRef)result;
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithAttributes(CTFontDescriptorRef descriptor, CFDictionaryRef attributes)
{
    if (!descriptor) return CTFontDescriptorCreateWithAttributes(attributes);
    NSMutableDictionary *dict = [(NSDictionary *)descriptor mutableCopy];
    if (attributes) {
        [dict addEntriesFromDictionary:(NSDictionary *)attributes];
    }
    CTFontDescriptorRef result = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)dict);
    [dict release];
    return result;
}

CTFontSymbolicTraits CTFontDescriptorGetSymbolicTraits(CTFontDescriptorRef descriptor)
{
    if (!descriptor) return 0;
    NSDictionary *traits = [(NSDictionary *)descriptor objectForKey:(id)kCTFontTraitsAttribute];
    NSNumber *symbolic = [traits objectForKey:(id)kCTFontSymbolicTrait];
    return symbolic ? (CTFontSymbolicTraits)[symbolic unsignedIntValue] : 0;
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithSymbolicTraits(CTFontDescriptorRef descriptor,
                                                                  CTFontSymbolicTraits value,
                                                                  CTFontSymbolicTraits mask)
{
    if (!descriptor) return NULL;

    NSDictionary *oldTraits = [(NSDictionary *)descriptor objectForKey:(id)kCTFontTraitsAttribute];
    NSMutableDictionary *traits = oldTraits ? [oldTraits mutableCopy] : [[NSMutableDictionary alloc] init];
    CTFontSymbolicTraits oldValue = CTFontDescriptorGetSymbolicTraits(descriptor);
    CTFontSymbolicTraits newValue = (oldValue & ~mask) | (value & mask);
    [traits setObject:[NSNumber numberWithUnsignedInt:newValue] forKey:(id)kCTFontSymbolicTrait];

    NSDictionary *changes = [NSDictionary dictionaryWithObject:traits forKey:(id)kCTFontTraitsAttribute];
    CTFontDescriptorRef result = CTFontDescriptorCreateCopyWithAttributes(descriptor, (CFDictionaryRef)changes);
    [traits release];
    return result;
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithFeature(CTFontDescriptorRef descriptor,
                                                          CFNumberRef featureTypeIdentifier,
                                                          CFNumberRef featureSelectorIdentifier)
{
    if (!descriptor || !featureTypeIdentifier || !featureSelectorIdentifier) return NULL;

    NSArray *oldSettings = [(NSDictionary *)descriptor objectForKey:(id)kCTFontFeatureSettingsAttribute];
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    for (NSDictionary *setting in oldSettings) {
        NSNumber *type = [setting objectForKey:(id)kCTFontFeatureTypeIdentifierKey];
        if (![type isEqual:(id)featureTypeIdentifier]) {
            [settings addObject:setting];
        }
    }
    NSDictionary *newSetting = [NSDictionary dictionaryWithObjectsAndKeys:
        (id)featureTypeIdentifier, (id)kCTFontFeatureTypeIdentifierKey,
        (id)featureSelectorIdentifier, (id)kCTFontFeatureSelectorIdentifierKey,
        nil];
    [settings addObject:newSetting];

    NSDictionary *changes = [NSDictionary dictionaryWithObject:settings forKey:(id)kCTFontFeatureSettingsAttribute];
    CTFontDescriptorRef result = CTFontDescriptorCreateCopyWithAttributes(descriptor, (CFDictionaryRef)changes);
    [settings release];
    return result;
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithVariation(CTFontDescriptorRef descriptor,
                                                            CFNumberRef variationIdentifier,
                                                            CGFloat variationValue)
{
    if (!descriptor || !variationIdentifier) return NULL;

    NSDictionary *oldVariations = [(NSDictionary *)descriptor objectForKey:(id)kCTFontVariationAttribute];
    NSMutableDictionary *variations = oldVariations ? [oldVariations mutableCopy] : [[NSMutableDictionary alloc] init];
    [variations setObject:[NSNumber numberWithDouble:variationValue] forKey:(id)variationIdentifier];

    NSDictionary *changes = [NSDictionary dictionaryWithObject:variations forKey:(id)kCTFontVariationAttribute];
    CTFontDescriptorRef result = CTFontDescriptorCreateCopyWithAttributes(descriptor, (CFDictionaryRef)changes);
    [variations release];
    return result;
}
