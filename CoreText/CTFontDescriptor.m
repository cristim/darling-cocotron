#import <CoreText/CTFontDescriptor.h>
#import <CoreText/CTFont.h>
#import "KTCoreTextInternal.h"
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSObjCRuntime.h>
#include <pthread.h>

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

bool KTCoreTextIsDescriptor(CFTypeRef object)
{
    return object != NULL && [(id)object isKindOfClass:[NSDictionary class]];
}

// A descriptor made here is an NSDictionary of attributes. One of any other class was made by another CoreText;
// its methods call back into these functions, so asking it for attributes would recurse without end.
CFDictionaryRef KTCoreTextDescriptorAttributes(CTFontDescriptorRef descriptor)
{
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    static NSMutableSet *reported;
    static NSDictionary *none;

    id object = (id)descriptor;
    if (object == nil || [object isKindOfClass:[NSDictionary class]])
        return (CFDictionaryRef)object;

    NSString *name = NSStringFromClass([object class]);
    pthread_mutex_lock(&lock);
    if (reported == nil) {
        reported = [[NSMutableSet alloc] init];
        none = [[NSDictionary alloc] init];
    }
    BOOL first = ![reported containsObject:name];
    if (first)
        [reported addObject:name];
    pthread_mutex_unlock(&lock);
    if (first)
        NSLog(@"CoreText: a font descriptor of class %@ was not created by this CoreText, so its attributes cannot be read here", name);
    return (CFDictionaryRef)none;
}

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
    return (CFDictionaryRef)[(id)KTCoreTextDescriptorAttributes(descriptor) copy];
}

CFTypeRef CTFontDescriptorCopyAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute)
{
    if (!descriptor || !attribute) return nil;
    id val = [(NSDictionary *)KTCoreTextDescriptorAttributes(descriptor) objectForKey:(id)attribute];
    return (CFTypeRef)[val retain];
}

CFArrayRef CTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes)
{
    if (!descriptor) return (CFArrayRef)[[NSArray array] retain];
    return (CFArrayRef)[[NSArray arrayWithObject:(id)descriptor] retain];
}

CTFontDescriptorRef CTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes)
{
    if (!descriptor) return NULL;
    return (CTFontDescriptorRef)[(id)descriptor retain];
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithAttributes(CTFontDescriptorRef descriptor, CFDictionaryRef attributes)
{
    if (!descriptor) return CTFontDescriptorCreateWithAttributes(attributes);
    NSMutableDictionary *dict = [(NSDictionary *)KTCoreTextDescriptorAttributes(descriptor) mutableCopy];
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
    NSDictionary *traits = [(NSDictionary *)KTCoreTextDescriptorAttributes(descriptor) objectForKey:(id)kCTFontTraitsAttribute];
    NSNumber *symbolic = [traits objectForKey:(id)kCTFontSymbolicTrait];
    return symbolic ? (CTFontSymbolicTraits)[symbolic unsignedIntValue] : 0;
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithSymbolicTraits(CTFontDescriptorRef descriptor,
                                                                  CTFontSymbolicTraits value,
                                                                  CTFontSymbolicTraits mask)
{
    if (!descriptor) return NULL;

    NSDictionary *oldTraits = [(NSDictionary *)KTCoreTextDescriptorAttributes(descriptor) objectForKey:(id)kCTFontTraitsAttribute];
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

    NSArray *oldSettings = [(NSDictionary *)KTCoreTextDescriptorAttributes(descriptor) objectForKey:(id)kCTFontFeatureSettingsAttribute];
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

    NSDictionary *oldVariations = [(NSDictionary *)KTCoreTextDescriptorAttributes(descriptor) objectForKey:(id)kCTFontVariationAttribute];
    NSMutableDictionary *variations = oldVariations ? [oldVariations mutableCopy] : [[NSMutableDictionary alloc] init];
    [variations setObject:[NSNumber numberWithDouble:variationValue] forKey:(id)variationIdentifier];

    NSDictionary *changes = [NSDictionary dictionaryWithObject:variations forKey:(id)kCTFontVariationAttribute];
    CTFontDescriptorRef result = CTFontDescriptorCreateCopyWithAttributes(descriptor, (CFDictionaryRef)changes);
    [variations release];
    return result;
}
