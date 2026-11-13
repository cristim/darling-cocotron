// Links CoreText without AppKit. Code in the shared cache calls CTFontDescriptorCreateWithAttributesAndOptions; Cocotron stops by
// name when it is missing, so the first call ends the process. The signature is a guess (see CTFontDescriptor.m): the result must
// be the descriptor CTFontDescriptorCreateWithAttributes makes from the same attributes, whatever the options word holds.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>

extern CTFontDescriptorRef CTFontDescriptorCreateWithAttributesAndOptions(CFDictionaryRef attributes, CFOptionFlags options);

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSDictionary *attributes = @{(id)kCTFontNameAttribute : @"Helvetica", (id)kCTFontSizeAttribute : @12.0};
        CTFontDescriptorRef plain = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attributes);
        for (CFOptionFlags options = 0; options <= 1; options++)
        {
            CTFontDescriptorRef made = CTFontDescriptorCreateWithAttributesAndOptions((CFDictionaryRef)attributes, options);
            expect(made != NULL, @"descriptor is created");
            expect(CFEqual(made, plain), @"same descriptor as CTFontDescriptorCreateWithAttributes");
            CFStringRef name = CTFontDescriptorCopyAttribute(made, kCTFontNameAttribute);
            expect(name != NULL && CFEqual(name, CFSTR("Helvetica")), @"name attribute is kept");
            CFRelease(name);
            CFRelease(made);
        }
        CTFontDescriptorRef empty = CTFontDescriptorCreateWithAttributesAndOptions(NULL, 0);
        expect(empty != NULL, @"NULL attributes make an empty descriptor");
        CFRelease(empty);
        CFRelease(plain);
        NSLog(@"coretext-font-descriptor-attributes-and-options: ok");
    }
    return 0;
}
