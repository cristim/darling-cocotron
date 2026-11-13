// NSSecureLayoutManager answers getGlyphs:range: with one bullet (or space) glyph per character, using only
// NSLayoutManager's and NSFont's public API, so it also works on top of another implementation of those classes.
#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#include <stdlib.h>
#include <objc/message.h>

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
        NSFont *font = [NSFont systemFontOfSize:14];
        NSTextStorage *storage = [[NSTextStorage alloc] initWithString:@"secret"];
        [storage setAttributes:@{NSFontAttributeName : font} range:NSMakeRange(0, 6)];
        Class secureClass = NSClassFromString(@"NSSecureLayoutManager");
        expect(secureClass != Nil && [secureClass isSubclassOfClass:[NSLayoutManager class]], @"NSSecureLayoutManager is an NSLayoutManager");
        NSLayoutManager *manager = [[secureClass alloc] init];
        NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(300, 100)];
        [manager addTextContainer:container];
        [storage addLayoutManager:manager];
        expect([manager textStorage] == storage, @"layout manager reports its text storage");

        unichar bullet = 0x2022, space = ' ';
        CGGlyph bulletGlyph = 0, spaceGlyph = 0;
        CTFontGetGlyphsForCharacters((CTFontRef)font, &bullet, &bulletGlyph, 1);
        CTFontGetGlyphsForCharacters((CTFontRef)font, &space, &spaceGlyph, 1);

        NSGlyph glyphs[6] = {0};
        ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, @selector(setEchosBullets:), YES);
        NSUInteger count = [manager getGlyphs:glyphs range:NSMakeRange(0, 6)];
        expect(count == 6, [NSString stringWithFormat:@"six glyphs returned, got %lu", (unsigned long)count]);
        for (int i = 0; i < 6; i++)
            expect(glyphs[i] == bulletGlyph, [NSString stringWithFormat:@"glyph %d is the bullet glyph", i]);

        ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, @selector(setEchosBullets:), NO);
        count = [manager getGlyphs:glyphs range:NSMakeRange(0, 6)];
        expect(count == 6, @"six glyphs returned without bullets");
        for (int i = 0; i < 6; i++)
            expect(glyphs[i] == spaceGlyph, [NSString stringWithFormat:@"glyph %d is the space glyph", i]);
    }
    NSLog(@"appkit-secure-layout-manager: all checks passed");
    return 0;
}
