// Links CoreText without AppKit. Usage: coretext-font-bridge plain|bridged|standin
//
// Where a class named NSCTFont exists (the shared cache's UIFoundation defines one, toll-free bridged to CTFont) the
// fonts CoreText makes are instances of it, holding their state themselves, so that class's methods, which call the
// CTFont functions with self, work. Without one fonts keep CoreText's own class.
#import <CoreText/CoreText.h>
#import <CoreText/KTFont.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

@interface NSObject (BridgeTest)
- (double)sizeThroughCoreText;
@end

// Not in the public headers: cache frameworks import them.
extern void *CTFontGetClientObject(CTFontRef font);
extern void CTFontSetClientObject(CTFontRef font, void *object);

extern bool CTFontIsSystemUIFont(CTFontRef font);
extern bool CTFontIsTextStyleFont(CTFontRef font);
extern bool CTFontIsAppleColorEmoji(CTFontRef font);
extern bool CTFontIsLastResort(CTFontRef font);
extern uint32_t CTFontGetUIFontType(CTFontRef font);
extern uint32_t CTFontGetPhysicalSymbolicTraits(CTFontRef font);

extern bool CTFontIsVertical(CTFontRef font);
extern bool CTFontHasTable(CTFontRef font, CTFontTableTag tag);

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

// Stands for the cache's class: toll-free bridged, so retain and release are the CF ones and it keeps no state.
static Class registerBridge(void)
{
    Class bridge = objc_allocateClassPair([NSObject class], "NSCTFont", 0);
    class_addMethod(bridge, @selector(retain), imp_implementationWithBlock(^id(id self) { return (id)CFRetain((CFTypeRef)self); }), "@@:");
    class_addMethod(bridge, @selector(release), imp_implementationWithBlock(^void(id self) { CFRelease((CFTypeRef)self); }), "v@:");
    class_addMethod(bridge, @selector(retainCount), imp_implementationWithBlock(^NSUInteger(id self) { return (NSUInteger)CFGetRetainCount((CFTypeRef)self); }), "Q@:");
    class_addMethod(bridge, @selector(sizeThroughCoreText), imp_implementationWithBlock(^double(id self) { return CTFontGetSize((CTFontRef)self); }), "d@:");
    objc_registerClassPair(bridge);
    return bridge;
}

static void checkFont(CTFontRef font)
{
    expect(!CTFontIsSystemUIFont(font) && !CTFontIsTextStyleFont(font) && !CTFontIsAppleColorEmoji(font) && !CTFontIsLastResort(font), @"an ordinary font is none of the special kinds");
    expect(!CTFontIsVertical(font), @"fonts are horizontal");
    expect(CTFontHasTable(font, 0x68656164) && !CTFontHasTable(font, 0x7a7a7a7a), @"a font has its head table and no zzzz table");
    expect(CTFontGetUIFontType(font) == (uint32_t)kCTFontUIFontNone, @"no UI font type");
    expect(CTFontGetPhysicalSymbolicTraits(font) == CTFontGetSymbolicTraits(font), @"physical traits are the traits");
    expect(CTFontGetSize(font) == 20, @"size");
    expect(CTFontGetAscent(font) > 0 && CTFontGetDescent(font) > 0 && CTFontGetAscent(font) < 40, @"metrics");
    UniChar characters[2] = {'A', 'i'};
    CGGlyph glyphs[2];
    CTFontGetGlyphsForCharacters(font, characters, glyphs, 2);
    expect(glyphs[0] != 0 && glyphs[1] != 0 && glyphs[0] != glyphs[1], @"glyphs");
    CGSize advances[2];
    expect(CTFontGetAdvancesForGlyphs(font, kCTFontOrientationDefault, glyphs, advances, 2) > 0, @"advances");
    CTFontRef bigger = CTFontCreateCopyWithAttributes(font, 40, NULL, NULL);
    expect(bigger != NULL && CTFontGetSize(bigger) == 40, @"copy with a new size");
    CFRelease(bigger);
}

int main(int argc, char **argv)
{
    @autoreleasepool
    {
        BOOL bridged = argc > 1 && strcmp(argv[1], "bridged") == 0;
        BOOL standin = argc > 1 && strcmp(argv[1], "standin") == 0;
        // A test process has no shared cache; the class below stands in for the cache's.
        if (bridged)
            setenv("KT_CORETEXT_BRIDGE_ANY_IMAGE", "1", 1);
        Class bridge = (bridged || standin) ? registerBridge() : Nil;
        expect(NSClassFromString(@"NSFont") == Nil, @"AppKit is not loaded");

        CTFontRef font = CTFontCreateWithName(CFSTR("DejaVu Sans"), 20, NULL);
        expect(font != NULL, @"a font is made");
        if (!bridged)
        {
            expect([(id)font isMemberOfClass:[KTFont class]], @"CoreText's own class is used, also with a same-named class outside the shared cache");
            checkFont(font);
            CFRelease(font);
            NSLog(@"coretext-font-bridge %s: ok", standin ? "standin" : "plain");
            return 0;
        }

        expect(object_getClass((id)font) == bridge, @"fonts are instances of the bridge class");
        expect(CFGetTypeID(font) == CTFontGetTypeID(), @"fonts have their own CF type");
        expect([(id)font sizeThroughCoreText] == 20, @"the bridge class's method reaches CoreText");
        checkFont(font);

        CTFontRef same = CTFontCreateWithName(CFSTR("DejaVu Sans"), 20, NULL);
        expect(CFEqual(font, same) && CFHash(font) == CFHash(same), @"equal name and size, equal fonts");
        CFRelease(same);

        // The cascade list lives in the object and is carried to a copy made with a new size.
        CFStringRef families[1] = {CFSTR("DejaVu Serif")};
        CFArrayRef cascade = CFArrayCreate(NULL, (const void **)families, 1, &kCFTypeArrayCallBacks);
        const void *keys[] = {kCTFontCascadeListAttribute};
        const void *values[] = {cascade};
        CFDictionaryRef attributes = CFDictionaryCreate(NULL, keys, values, 1, &kCFTypeDictionaryKeyCallBacks,
                                                        &kCFTypeDictionaryValueCallBacks);
        CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes(attributes);
        CTFontRef withCascade = CTFontCreateCopyWithAttributes(font, 24, NULL, descriptor);
        CFTypeRef read = CTFontCopyAttribute(withCascade, kCTFontCascadeListAttribute);
        expect(read != NULL && CFEqual(read, cascade), @"the cascade list is kept in the font");
        CFRelease(read);
        CTFontRef resized = CTFontCreateCopyWithAttributes(withCascade, 30, NULL, NULL);
        read = CTFontCopyAttribute(resized, kCTFontCascadeListAttribute);
        expect(read != NULL && CFEqual(read, cascade), @"a copy keeps the cascade list");
        CFRelease(read);
        CFRelease(resized);
        CFRelease(withCascade);
        CFRelease(descriptor);
        CFRelease(attributes);
        CFRelease(cascade);

        int marker;
        expect(CTFontGetClientObject(font) == NULL, @"no client object at first");
        CTFontSetClientObject(font, &marker);
        expect(CTFontGetClientObject(font) == &marker, @"the client object is kept in the font");
        CTFontSetClientObject(font, NULL);

        // Held through both retain families.
        NSArray *held = [NSArray arrayWithObject:(id)font];
        CFRelease(font);
        expect(CTFontGetSize((CTFontRef)[held objectAtIndex:0]) == 20, @"still alive in the array");
        NSLog(@"coretext-font-bridge bridged: ok");
    }
    return 0;
}
