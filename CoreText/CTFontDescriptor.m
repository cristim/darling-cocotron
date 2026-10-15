#import <CoreText/CTFontDescriptor.h>

#import <Foundation/Foundation.h>
#import <Onyx2D/O2Font_freetype.h>

const CFStringRef kCTFontURLAttribute = CFSTR("NSCTFontFileURLAttribute");
const CFStringRef kCTFontNameAttribute = CFSTR("NSFontNameAttribute");
const CFStringRef kCTFontDisplayNameAttribute = CFSTR("NSFontVisibleNameAttribute");
const CFStringRef kCTFontFamilyNameAttribute = CFSTR("NSFontFamilyAttribute");
const CFStringRef kCTFontStyleNameAttribute = CFSTR("NSFontFaceAttribute");
const CFStringRef kCTFontTraitsAttribute = CFSTR("NSCTFontTraitsAttribute");
const CFStringRef kCTFontVariationAttribute = CFSTR("NSCTFontVariationAttribute");
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
const CFStringRef kCTFontCollectionRemoveDuplicatesOption = CFSTR("kCTFontCollectionRemoveDuplicatesOption");

CTFontDescriptorRef CTFontDescriptorCreateWithAttributes(CFDictionaryRef attributes)
{
    if (!attributes)
        return NULL;
    /* Back descriptors directly by an immutable dictionary copy. */
    return (CTFontDescriptorRef)CFDictionaryCreateCopy(NULL, attributes);
}

CFTypeRef CTFontDescriptorCopyAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute)
{
    CFTypeRef value;
    if (!descriptor || !attribute)
        return nil;
    value = CFDictionaryGetValue((CFDictionaryRef)descriptor, attribute);
    if (value)
        CFRetain(value);
    return value;
}

/* Enumerate actual installed faces, rather than returning the query itself.
 * FcFontList does not substitute an unrelated font for a missing family. */
CFArrayRef CTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef descriptor,
                                                        CFSetRef mandatoryAttributes)
{
    if (!descriptor)
        return NULL;
    NSDictionary *query = (NSDictionary *)descriptor;
    FcPattern *pattern = FcPatternCreate();
    const CFStringRef keys[] = { kCTFontFamilyNameAttribute, kCTFontNameAttribute,
                                kCTFontStyleNameAttribute, kCTFontDisplayNameAttribute };
    const char *properties[] = { FC_FAMILY, FC_POSTSCRIPT_NAME, FC_STYLE, FC_FULLNAME };
    for (unsigned i = 0; i < sizeof(keys) / sizeof(keys[0]); ++i) {
        id value = [query objectForKey:(id)keys[i]];
        if ([value isKindOfClass:[NSString class]])
            FcPatternAddString(pattern, properties[i], (const FcChar8 *)[value UTF8String]);
    }
    FcObjectSet *objects = FcObjectSetBuild(FC_FAMILY, FC_POSTSCRIPT_NAME,
                                           FC_STYLE, FC_FULLNAME, FC_FILE, NULL);
    FcFontSet *fonts = FcFontList(O2FontSharedFontConfig(), pattern, objects);
    CFMutableArrayRef matchesArray = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    for (int i = 0; fonts && i < fonts->nfont; ++i) {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        for (unsigned j = 0; j < sizeof(keys) / sizeof(keys[0]); ++j) {
            FcChar8 *text;
            if (FcPatternGetString(fonts->fonts[i], properties[j], 0, &text) == FcResultMatch) {
                NSString *value = [NSString stringWithUTF8String:(const char *)text];
                if (value) [attributes setObject:value forKey:(id)keys[j]];
            }
        }
        FcChar8 *file;
        if (FcPatternGetString(fonts->fonts[i], FC_FILE, 0, &file) == FcResultMatch) {
            NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:(const char *)file]];
            if (url) [attributes setObject:url forKey:(id)kCTFontURLAttribute];
        }
        /* Point size is a request, not an installed-face property. */
        id size = [query objectForKey:(id)kCTFontSizeAttribute];
        if (size) [attributes setObject:size forKey:(id)kCTFontSizeAttribute];
        BOOL matches = YES;
        for (id key in (NSSet *)mandatoryAttributes) {
            id expected = [query objectForKey:key];
            if (!expected || ![expected isEqual:[attributes objectForKey:key]]) {
                matches = NO;
                break;
            }
        }
        if (matches) {
            CTFontDescriptorRef match = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attributes);
            CFArrayAppendValue(matchesArray, match);
            CFRelease(match);
        }
    }
    if (fonts) FcFontSetDestroy(fonts);
    FcObjectSetDestroy(objects);
    FcPatternDestroy(pattern);
    return matchesArray;
}

CTFontDescriptorRef CTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef descriptor,
                                                                CFSetRef mandatoryAttributes)
{
    CFArrayRef matches = CTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatoryAttributes);
    CTFontDescriptorRef result = NULL;
    if (matches) {
        if (CFArrayGetCount(matches))
            result = (CTFontDescriptorRef)CFRetain(CFArrayGetValueAtIndex(matches, 0));
        CFRelease(matches);
    }
    return result;
}

CFTypeRef CTFontDescriptorCopyLocalizedAttribute(CTFontDescriptorRef descriptor,
                                                CFStringRef attribute, CFStringRef *language)
{
    /* Fall back to the canonical name when localized font metadata is absent.
     * A NULL language output is valid (Chromium uses it for family names). */
    if (language) *language = NULL;
    return CTFontDescriptorCopyAttribute(descriptor, attribute);
}
