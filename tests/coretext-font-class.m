// Links CoreText without AppKit, as command-line tools do.
#import <CoreText/CoreText.h>
#import <CoreText/KTFont.h>
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

@interface OtherFont : KTFont
@end

@implementation OtherFont
@end

int main(void)
{
    @autoreleasepool
    {
        expect(NSClassFromString(@"NSFont") == Nil, @"AppKit is not loaded");

        CTFontRef font = CTFontCreateWithName(CFSTR("DejaVu Sans"), 20, NULL);
        expect(font != NULL && [(id)font isMemberOfClass:[KTFont class]], @"CoreText's own font class is used");
        expect(CTFontGetSize(font) == 20, @"size");
        expect(CTFontGetAscent(font) > 0 && CTFontGetDescent(font) > 0 && CTFontGetAscent(font) < 40,
               @"ascent and descent are positive points at this size");
        expect(CTFontGetUnderlineThickness(font) > 0 && CTFontGetUnderlinePosition(font) < 0,
               @"underline metrics come from the face");
        expect(CTFontGetGlyphCount(font) > 0, @"glyph count");

        UniChar characters[2] = {'A', 'i'};
        CGGlyph glyphs[2];
        CTFontGetGlyphsForCharacters(font, characters, glyphs, 2);
        expect(glyphs[0] != 0 && glyphs[1] != 0 && glyphs[0] != glyphs[1], @"characters map to glyphs");
        CGSize advances[2];
        double total = CTFontGetAdvancesForGlyphs(font, kCTFontOrientationDefault, glyphs, advances, 2);
        expect(advances[0].width > advances[1].width && advances[1].width > 0 &&
                   total == advances[0].width + advances[1].width,
               @"advances and their sum");
        expect(CTFontGetAdvancesForGlyphs(font, kCTFontOrientationDefault, glyphs, NULL, 2) == total,
               @"the sum without an advances buffer");

        CTFontRef larger = CTFontCreateCopyWithAttributes(font, 40, NULL, NULL);
        expect(CTFontGetSize(larger) == 40 && CTFontGetAscent(larger) > CTFontGetAscent(font) * 1.9,
               @"copies scale their metrics");
        CFStringRef name = CTFontCopyFullName(font);
        expect(name != NULL && CFStringGetLength(name) > 0, @"full name");

        BOOL raised = NO;
        @try {
            _CTFontSetConcreteClass([OtherFont class]);
        } @catch (NSException *exception) {
            raised = [exception.name isEqual:NSInternalInconsistencyException];
        }
        expect(raised, @"no second font class once fonts exist");
        CTFontRef after = CTFontCreateWithName(CFSTR("DejaVu Sans"), 12, NULL);
        expect([(id)after isMemberOfClass:[KTFont class]], @"fonts keep one class");

        CFRelease(name);
        CFRelease(after);
        CFRelease(larger);
        CFRelease(font);
        NSLog(@"PASS: CoreText fonts work without AppKit and keep a single class");
    }
    return 0;
}
