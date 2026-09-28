#import <AppKit/AppKit.h>
#import <CoreText/KTFont.h>
#include <stdlib.h>

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
        CTFontRef ctFont = CTFontCreateWithName(CFSTR("DejaVu Sans"), 18, NULL);
        NSFont *asFont = (NSFont *)ctFont;
        expect([asFont isKindOfClass:[NSFont class]], @"CTFontCreateWithName returns an NSFont");
        expect(asFont.pointSize == 18 && [asFont.fontName isEqual:@"DejaVu Sans"], @"it answers NSFont's API");
        expect(asFont.ascender == CTFontGetAscent(ctFont) && asFont.descender == -CTFontGetDescent(ctFont),
               @"NSFont and CTFont metrics agree");

        NSFont *font = [NSFont fontWithName:@"DejaVu Sans" size:14];
        CTFontRef bridged = (CTFontRef)font;
        expect(CTFontGetSize(bridged) == 14, @"an NSFont works in CTFontGetSize");
        NSString *name = (NSString *)CTFontCopyFullName(bridged);
        expect([name isEqual:@"DejaVu Sans"], @"an NSFont works in CTFontCopyFullName");
        [name release];
        UniChar character = 'W';
        CGGlyph glyph = 0;
        CTFontGetGlyphsForCharacters(bridged, &character, &glyph, 1);
        CGSize advance;
        CTFontGetAdvancesForGlyphs(bridged, kCTFontOrientationDefault, &glyph, &advance, 1);
        BOOL nominal = NO;
        NSPoint position = [font positionOfGlyph:glyph precededByGlyph:NSNullGlyph isNominal:&nominal];
        expect(glyph != 0 && advance.width > 0 && position.x == advance.width && nominal,
               @"glyphs and advances agree between the two APIs");

        CTFontRef copy = CTFontCreateCopyWithAttributes(bridged, 28, NULL, NULL);
        expect([(id)copy isKindOfClass:[NSFont class]] && [(NSFont *)copy pointSize] == 28,
               @"copies of an NSFont are NSFonts");

        CTFontRef menu = CTFontCreateUIFontForLanguage(kCTFontMenuItemFontType, 0, NULL);
        expect(menu == NULL || [(id)menu isKindOfClass:[NSFont class]], @"UI fonts are NSFonts");

        CTFontRef twin = CTFontCreateWithName(CFSTR("DejaVu Sans"), 14, NULL);
        expect((id)twin != font, @"CoreText's fonts are not the cached ones");
        CFRelease(twin);
        expect([NSFont fontWithName:@"DejaVu Sans" size:14] == font,
               @"releasing a same-named CoreText font keeps the cached NSFont");

        BOOL raised = NO;
        @try {
            _CTFontSetConcreteClass([KTFont class]);
        } @catch (NSException *exception) {
            raised = [exception.name isEqual:NSInternalInconsistencyException];
        }
        expect(raised, @"CoreText's class cannot be switched away from NSFont");

        if (menu != NULL)
            CFRelease(menu);
        CFRelease(copy);
        CFRelease(ctFont);
        NSLog(@"PASS: CTFont and NSFont are the same objects");
    }
    return 0;
}
