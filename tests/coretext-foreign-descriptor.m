// Links CoreText without AppKit. A descriptor made by another CoreText (the shared cache's, whose methods call the
// CTFontDescriptor functions with self) must not make this CoreText recurse through those methods.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface ForeignDescriptor : NSObject
@end

@implementation ForeignDescriptor
- (id)objectForKey:(id)key { return [(id)CTFontDescriptorCopyAttribute((CTFontDescriptorRef)self, (CFStringRef)key) autorelease]; }
- (id)copyWithZone:(NSZone *)zone { return (id)CTFontDescriptorCopyAttributes((CTFontDescriptorRef)self); }
@end

int main(void)
{
    @autoreleasepool
    {
        ForeignDescriptor *foreign = [[ForeignDescriptor alloc] init];
        CFTypeRef value = CTFontDescriptorCopyAttribute((CTFontDescriptorRef)foreign, kCTFontNameAttribute);
        expect(value == NULL, @"a foreign descriptor has no attributes here");
        CFDictionaryRef none = CTFontDescriptorCopyAttributes((CTFontDescriptorRef)foreign);
        expect(none != NULL && CFDictionaryGetCount(none) == 0, @"a foreign descriptor copies as empty");
        CFRelease(none);
        CTFontRef font = CTFontCreateWithFontDescriptor((CTFontDescriptorRef)foreign, 12, NULL);
        expect(font != NULL, @"a font can still be made from it");
        CFRelease(font);
        CTFontDescriptorRef derived = CTFontDescriptorCreateCopyWithSymbolicTraits(
                (CTFontDescriptorRef)foreign, kCTFontTraitBold, kCTFontTraitBold);
        expect(derived != NULL && CTFontDescriptorGetSymbolicTraits(derived) == kCTFontTraitBold,
               @"a copy made from it carries the requested traits");
        CFRelease(derived);
        NSLog(@"coretext-foreign-descriptor: ok");
    }
    return 0;
}
