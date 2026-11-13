// Links CoreText without AppKit. Usage: coretext-font-descriptor-bridge plain|bridged
//
// A font descriptor is a CF object whose attributes live in it. When a class named NSCTFontDescriptor exists in the
// process (the shared cache's UIFoundation defines one) new descriptors are instances of it, so that class's methods,
// which call the CTFontDescriptor functions with self, work. Without such a class descriptors keep their own class.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

// Stands for the cache's class: toll-free bridged, so retain and release are the CF ones and it keeps no state.
// Registered only in the bridged run, before the first descriptor is made.
static Class registerBridge(void)
{
    Class bridge = objc_allocateClassPair([NSObject class], "NSCTFontDescriptor", 0);
    class_addMethod(bridge, @selector(retain), imp_implementationWithBlock(^id(id self) { return (id)CFRetain((CFTypeRef)self); }), "@@:");
    class_addMethod(bridge, @selector(release), imp_implementationWithBlock(^void(id self) { CFRelease((CFTypeRef)self); }), "v@:");
    class_addMethod(bridge, @selector(retainCount), imp_implementationWithBlock(^NSUInteger(id self) { return (NSUInteger)CFGetRetainCount((CFTypeRef)self); }), "Q@:");
    class_addMethod(bridge, @selector(fontAttributes), imp_implementationWithBlock(^id(id self) { return [(id)CTFontDescriptorCopyAttributes((CTFontDescriptorRef)self) autorelease]; }), "@@:");
    objc_registerClassPair(bridge);
    return bridge;
}

extern bool CTFontDescriptorIsSystemUIFont(CTFontDescriptorRef descriptor);
extern bool CTFontDescriptorIsAppleFont(CTFontDescriptorRef descriptor);
extern bool CTFontDescriptorHasPostScriptNameAlias(CTFontDescriptorRef descriptor);
extern bool CTFontDescriptorIsValid(CTFontDescriptorRef descriptor);

static CTFontDescriptorRef makeDescriptor(void)
{
    const void *keys[] = {kCTFontNameAttribute, kCTFontSizeAttribute};
    double size = 14;
    CFNumberRef sizeNumber = CFNumberCreate(NULL, kCFNumberDoubleType, &size);
    const void *values[] = {CFSTR("TestFont"), sizeNumber};
    CFDictionaryRef attributes = CFDictionaryCreate(NULL, keys, values, 2, &kCFTypeDictionaryKeyCallBacks,
                                                    &kCFTypeDictionaryValueCallBacks);
    CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes(attributes);
    CFRelease(attributes);
    CFRelease(sizeNumber);
    return descriptor;
}

static void checkAttributes(CTFontDescriptorRef descriptor)
{
    CFTypeRef name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
    expect(name != NULL && CFEqual(name, CFSTR("TestFont")), @"attribute read back");
    CFRelease(name);
    CFDictionaryRef all = CTFontDescriptorCopyAttributes(descriptor);
    expect(all != NULL && CFDictionaryGetCount(all) == 2, @"all attributes read back");
    CFRelease(all);
    CTFontDescriptorRef bold = CTFontDescriptorCreateCopyWithSymbolicTraits(descriptor, kCTFontTraitBold, kCTFontTraitBold);
    expect(bold != NULL && CTFontDescriptorGetSymbolicTraits(bold) == kCTFontTraitBold, @"symbolic traits copy");
    expect(CTFontDescriptorGetSymbolicTraits(descriptor) == 0, @"the original is unchanged");
    CFTypeRef copiedName = CTFontDescriptorCopyAttribute(bold, kCTFontNameAttribute);
    expect(copiedName != NULL && CFEqual(copiedName, CFSTR("TestFont")), @"copy keeps the name");
    CFRelease(copiedName);
    CFRelease(bold);

    expect(!CTFontDescriptorIsSystemUIFont(descriptor) && !CTFontDescriptorIsAppleFont(descriptor) && !CTFontDescriptorHasPostScriptNameAlias(descriptor), @"an ordinary descriptor is none of the special kinds");
    expect(CTFontDescriptorIsValid(descriptor), @"it is valid");
    CFStringRef language = (CFStringRef)descriptor;
    CFTypeRef localized = CTFontDescriptorCopyLocalizedAttribute(descriptor, kCTFontNameAttribute, &language);
    expect(localized != NULL && CFEqual(localized, CFSTR("TestFont")) && language == NULL, @"localized attribute");
    CFRelease(localized);
    CFArrayRef matches = CTFontDescriptorCreateMatchingFontDescriptorsWithOptions(descriptor, NULL, NULL);
    expect(matches != NULL && CFArrayGetCount(matches) == 1, @"matching with options returns one descriptor");
    CTFontDescriptorRef matched = (CTFontDescriptorRef)CFArrayGetValueAtIndex(matches, 0);
    CFTypeRef matchedName = CTFontDescriptorCopyAttribute(matched, kCTFontNameAttribute);
    expect(matchedName != NULL && CFEqual(matchedName, CFSTR("TestFont")), @"the match keeps what the descriptor says");
    CFRelease(matchedName);
    CFTypeRef family = CTFontDescriptorCopyAttribute(matched, kCTFontFamilyNameAttribute);
    CFTypeRef face = CTFontDescriptorCopyAttribute(matched, kCTFontPostScriptNameAttribute);
    expect(family != NULL && face != NULL, @"the match carries the family and PostScript names");
    CFRelease(family);
    CFRelease(face);
    CFRelease(matches);
}

int main(int argc, char **argv)
{
    @autoreleasepool
    {
        BOOL bridged = argc > 1 && strcmp(argv[1], "bridged") == 0;
        // A test process has no shared cache; the class below stands in for the cache's.
        if (bridged)
            setenv("KT_CORETEXT_BRIDGE_ANY_IMAGE", "1", 1);
        BOOL standin = argc > 1 && strcmp(argv[1], "standin") == 0;
        Class bridge = (bridged || standin) ? registerBridge() : Nil;
        expect(NSClassFromString(@"NSFont") == Nil, @"AppKit is not loaded");

        if (!bridged)
        {
            CTFontDescriptorRef descriptor = makeDescriptor();
            expect(CFGetTypeID(descriptor) == CTFontDescriptorGetTypeID(), @"descriptors have their own CF type");
            expect(CTFontDescriptorGetTypeID() != CFDictionaryGetTypeID(), @"the type is not a dictionary's");
            if (standin)
                expect(object_getClass((id)descriptor) != bridge, @"a same-named class outside the shared cache is not used");
            else
                expect(NSClassFromString(@"NSCTFontDescriptor") == Nil, @"no bridge class in this process");
            checkAttributes(descriptor);
            CTFontDescriptorRef same = makeDescriptor();
            expect(CFEqual(descriptor, same) && CFHash(descriptor) == CFHash(same), @"equal attributes, equal descriptors");
            CFRelease(same);
            CFRelease(descriptor);
            NSLog(@"coretext-font-descriptor-bridge %s: ok", standin ? "standin" : "plain");
            return 0;
        }

        CTFontDescriptorRef descriptor = makeDescriptor();
        expect(CFGetTypeID(descriptor) == CTFontDescriptorGetTypeID(), @"descriptors have their own CF type");
        expect(object_getClass((id)descriptor) == bridge, @"descriptors are instances of the bridge class");
        checkAttributes(descriptor);
        expect([[(id)descriptor fontAttributes] count] == 2, @"the bridge class's method reaches CoreText");

        // Held and released through both retain families: the count must stay consistent.
        NSArray *held = [NSArray arrayWithObject:(id)descriptor];
        CFRelease(descriptor);
        expect([held count] == 1 && CFGetRetainCount([held objectAtIndex:0]) >= 1, @"retained by the array");
        CTFontRef font = CTFontCreateWithFontDescriptor((CTFontDescriptorRef)[held objectAtIndex:0], 0, NULL);
        expect(font != NULL && CTFontGetSize(font) == 14, @"a font from the descriptor takes its size");
        CFRelease(font);
        NSLog(@"coretext-font-descriptor-bridge bridged: ok");
    }
    return 0;
}
