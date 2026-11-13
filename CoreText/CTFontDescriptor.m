#import <CoreText/CTFontDescriptor.h>
#import <CoreText/CTFont.h>
#import "KTCoreTextInternal.h"
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSObjCRuntime.h>
#include <CoreFoundation/CFRuntime.h>
#import <objc/runtime.h>
#include <dlfcn.h>
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

// A descriptor is a CF object that holds its attributes. Where a class named NSCTFontDescriptor exists (the shared
// cache's UIFoundation defines one, toll-free bridged to CTFontDescriptor), descriptors are made instances of it, so
// that class's methods, which call the functions below with self, find the attributes in the object. Without such a
// class they keep CF's own class. The class is looked up, never assumed.
struct __CTFontDescriptor {
    CFRuntimeBase base;
    CFDictionaryRef attributes;
};

static void finalizeDescriptor(CFTypeRef value)
{
    CFRelease(((struct __CTFontDescriptor *)value)->attributes);
}

static Boolean equalDescriptors(CFTypeRef a, CFTypeRef b)
{
    return CFEqual(((struct __CTFontDescriptor *)a)->attributes, ((struct __CTFontDescriptor *)b)->attributes);
}

static CFHashCode hashDescriptor(CFTypeRef value)
{
    return CFHash(((struct __CTFontDescriptor *)value)->attributes);
}

static const CFRuntimeClass descriptorClass = {
    0, "CTFontDescriptor", NULL, NULL, finalizeDescriptor, equalDescriptors, hashDescriptor, NULL, NULL,
};
static CFTypeID descriptorType;
static pthread_once_t descriptorTypeOnce = PTHREAD_ONCE_INIT;

static void registerDescriptorType(void)
{
    descriptorType = _CFRuntimeRegisterClass(&descriptorClass);
}

CFTypeID CTFontDescriptorGetTypeID(void)
{
    pthread_once(&descriptorTypeOnce, registerDescriptorType);
    return descriptorType;
}

static pthread_once_t bridgeOnce = PTHREAD_ONCE_INIT;

// Tells CF that objects of a CF type are instances of the class of that name, as CF does for its own bridged types:
// CF then gives every new object of the type that class as its isa and keeps handling retain, release, equality and
// hash itself. Returns false, and reports it, when CoreFoundation has no registration function; false, quietly, when
// no class has that name.
bool KTCoreTextBridgeType(CFTypeID type, const char *className)
{
    if (objc_getClass(className) == Nil)
        return false;
    void (*registerClass)(CFTypeID, const char *) = (void (*)(CFTypeID, const char *))dlsym(RTLD_DEFAULT, "_CFRuntimeBridgeClasses");
    if (registerClass == NULL) {
        NSLog(@"CoreText: class %s exists but CoreFoundation cannot bridge a type to it; those objects stay plain CF objects", className);
        return false;
    }
    registerClass(type, className);
    return true;
}

static void bridgeDescriptorClass(void)
{
    KTCoreTextBridgeType(CTFontDescriptorGetTypeID(), "NSCTFontDescriptor");
}

bool KTCoreTextIsDescriptor(CFTypeRef object)
{
    return object != NULL && CFGetTypeID(object) == CTFontDescriptorGetTypeID();
}

// A descriptor of any other kind was made by another CoreText; its methods call back into these functions, so asking
// it for attributes would recurse without end.
CFDictionaryRef KTCoreTextDescriptorAttributes(CTFontDescriptorRef descriptor)
{
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    static NSMutableSet *reported;
    static NSDictionary *none;

    if (descriptor == NULL)
        return NULL;
    if (KTCoreTextIsDescriptor(descriptor))
        return ((struct __CTFontDescriptor *)descriptor)->attributes;

    NSString *name = NSStringFromClass([(id)descriptor class]);
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

CTFontDescriptorRef CTFontDescriptorCreateWithAttributes(CFDictionaryRef attributes)
{
    CFDictionaryRef snapshot = attributes != NULL
            ? CFDictionaryCreateCopy(kCFAllocatorDefault, attributes)
            : CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                 &kCFTypeDictionaryValueCallBacks);
    pthread_once(&bridgeOnce, bridgeDescriptorClass);
    struct __CTFontDescriptor *descriptor = (struct __CTFontDescriptor *)_CFRuntimeCreateInstance(
            kCFAllocatorDefault, CTFontDescriptorGetTypeID(), sizeof(*descriptor) - sizeof(CFRuntimeBase), NULL);
    if (descriptor == NULL) {
        CFRelease(snapshot);
        return NULL;
    }
    descriptor->attributes = snapshot;
    return descriptor;
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

// Only this CoreText's own fonts exist, in no localization but the one the attribute holds, so the language is
// reported as unknown (documented as NULL when the attribute is not localized).
CFTypeRef CTFontDescriptorCopyLocalizedAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute, CFStringRef *language)
{
    if (language != NULL)
        *language = NULL;
    return CTFontDescriptorCopyAttribute(descriptor, attribute);
}

CFArrayRef CTFontDescriptorCreateMatchingFontDescriptorsWithOptions(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes, CFDictionaryRef options)
{
    return CTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatoryAttributes);
}

CFArrayRef CTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes)
{
    if (!descriptor) return CFArrayCreate(kCFAllocatorDefault, NULL, 0, &kCFTypeArrayCallBacks);
    return CFArrayCreate(kCFAllocatorDefault, (const void **)&descriptor, 1, &kCFTypeArrayCallBacks);
}

CTFontDescriptorRef CTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes)
{
    if (!descriptor) return NULL;
    return (CTFontDescriptorRef)CFRetain(descriptor);
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
