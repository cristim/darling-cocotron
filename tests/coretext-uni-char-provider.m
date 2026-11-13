// The private chunked-text entry points other frameworks use: CTLineCreateWithUniCharProvider,
// CTTypesetterCreateWithUniCharProviderAndOptions, CTRunGetInitialAdvance, CTParagraphStyleSetCompositionLanguage.
// Declarations follow the open WebKit SPI header. Expected glyphs and widths come from CTFont, not from CTLine code.
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

typedef const UniChar *(*CTUniCharProviderCallback)(CFIndex stringIndex, CFIndex *charCount, CFDictionaryRef *attributes, void *refCon);
typedef void (*CTUniCharDisposeCallback)(const UniChar *chars, void *refCon);
extern CTLineRef CTLineCreateWithUniCharProvider(CTUniCharProviderCallback, CTUniCharDisposeCallback, void *refCon);
extern CTTypesetterRef CTTypesetterCreateWithUniCharProviderAndOptions(CTUniCharProviderCallback, CTUniCharDisposeCallback, void *refCon, CFDictionaryRef options);
extern CGSize CTRunGetInitialAdvance(CTRunRef);
typedef uint8_t CTCompositionLanguage;
extern void CTParagraphStyleSetCompositionLanguage(CTParagraphStyleRef, CTCompositionLanguage);

static int failures;
#define CHECK(cond, ...) do { if (cond) printf("PASS "); else { printf("FAIL "); ++failures; } printf(__VA_ARGS__); printf("\n"); } while (0)

typedef struct { const UniChar *text; CFIndex length; CFIndex chunk; CFDictionaryRef attributes[2]; int disposed; } Source;

// hands out `chunk` characters per request, alternating between the two attribute dictionaries
static const UniChar *provide(CFIndex index, CFIndex *count, CFDictionaryRef *attributes, void *refCon) {
    Source *source = refCon;
    if (index < 0 || index >= source->length) return NULL;
    *count = source->length - index < source->chunk ? source->length - index : source->chunk;
    *attributes = source->attributes[(index / source->chunk) % 2];
    return source->text + index;
}
static void dispose(const UniChar *chars, void *refCon) { ((Source *)refCon)->disposed++; }

static CGFloat advanceOf(CTFontRef font, UniChar c, CGGlyph *glyph) {
    CGSize size;
    CTFontGetGlyphsForCharacters(font, &c, glyph, 1);
    CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, glyph, &size, 1);
    return size.width;
}

int main(void) { @autoreleasepool {
    CTFontRef small = CTFontCreateWithName(CFSTR("DejaVu Sans"), 12, NULL);
    CTFontRef large = CTFontCreateWithName(CFSTR("DejaVu Sans"), 24, NULL);
    const void *keys[] = {kCTFontAttributeName};
    const void *smallValues[] = {small}, *largeValues[] = {large};
    CFDictionaryRef smallAttrs = CFDictionaryCreate(NULL, keys, smallValues, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryRef largeAttrs = CFDictionaryCreate(NULL, keys, largeValues, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    // 6 characters in chunks of 3: the first chunk is 12 pt, the second 24 pt
    static const UniChar text[] = {'a', 'b', 'c', 'D', 'E', 'F'};
    Source source = { text, 6, 3, { smallAttrs, largeAttrs }, 0 };
    CGGlyph glyphs[6]; double width = 0;
    for (int i = 0; i < 6; ++i) width += advanceOf(i < 3 ? small : large, text[i], &glyphs[i]);

    CTLineRef line = CTLineCreateWithUniCharProvider(provide, dispose, &source);
    CHECK(line != NULL, "a line is created from the provider");
    CHECK(source.disposed == 2, "dispose ran once per chunk (%d)", source.disposed);
    if (line) {
        CFRange range = CTLineGetStringRange(line);
        CHECK(range.location == 0 && range.length == 6, "string range covers both chunks (%ld,%ld)", (long)range.location, (long)range.length);
        CHECK(CTLineGetGlyphCount(line) == 6, "six glyphs");
        CHECK(fabs(CTLineGetTypographicBounds(line, NULL, NULL, NULL) - width) < 0.001, "width %.3f is the 12 pt advances plus the 24 pt advances (%.3f)", CTLineGetTypographicBounds(line, NULL, NULL, NULL), width);
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        CHECK(CFArrayGetCount(runs) == 2, "one run per attribute chunk (%ld)", (long)CFArrayGetCount(runs));
        if (CFArrayGetCount(runs) == 2) {
            CTRunRef first = (CTRunRef)CFArrayGetValueAtIndex(runs, 0), second = (CTRunRef)CFArrayGetValueAtIndex(runs, 1);
            CFRange r1 = CTRunGetStringRange(first), r2 = CTRunGetStringRange(second);
            CHECK(r1.location == 0 && r1.length == 3 && r2.location == 3 && r2.length == 3, "run string ranges are the chunks");
            CTFontRef f1 = (CTFontRef)CFDictionaryGetValue(CTRunGetAttributes(first), kCTFontAttributeName);
            CTFontRef f2 = (CTFontRef)CFDictionaryGetValue(CTRunGetAttributes(second), kCTFontAttributeName);
            CHECK(f1 && f2 && CTFontGetSize(f1) == 12 && CTFontGetSize(f2) == 24, "run fonts follow the chunk attributes");
            CGGlyph g[3]; CTRunGetGlyphs(second, CFRangeMake(0, 0), g);
            CHECK(memcmp(g, glyphs + 3, sizeof(g)) == 0, "second run glyphs are those of D E F");
            CGSize initial = CTRunGetInitialAdvance(first);
            CHECK(initial.width == 0 && initial.height == 0, "no shaping, so no initial advance");
        }
        CFRelease(line);
    }
    Source empty = { text, 0, 3, { smallAttrs, largeAttrs }, 0 };
    CTLineRef none = CTLineCreateWithUniCharProvider(provide, NULL, &empty);
    CHECK(none != NULL && CTLineGetGlyphCount(none) == 0, "an empty provider yields an empty line");
    if (none) CFRelease(none);
    CHECK(CTLineCreateWithUniCharProvider(NULL, NULL, NULL) == NULL, "no provider, no line");

    Source second = { text, 6, 3, { smallAttrs, largeAttrs }, 0 };
    CTTypesetterRef typesetter = CTTypesetterCreateWithUniCharProviderAndOptions(provide, dispose, &second, NULL);
    CHECK(typesetter != NULL, "a typesetter is created from the provider");
    if (typesetter) {
        CTLineRef all = CTTypesetterCreateLine(typesetter, CFRangeMake(0, 0));
        CHECK(all != NULL && CTLineGetGlyphCount(all) == 6 && fabs(CTLineGetTypographicBounds(all, NULL, NULL, NULL) - width) < 0.001, "its line has the same glyphs and width");
        CHECK(CTTypesetterSuggestLineBreak(typesetter, 0, 1000) == 6, "it sees all six characters");
        if (all) CFRelease(all);
        CFRelease(typesetter);
    }

    CTParagraphStyleRef style = CTParagraphStyleCreate(NULL, 0);
    CTTextAlignment alignment = kCTTextAlignmentCenter;
    CTParagraphStyleSetting setting = { kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment };
    CTParagraphStyleRef centered = CTParagraphStyleCreate(&setting, 1);
    CTParagraphStyleSetCompositionLanguage(centered, 1);
    CTParagraphStyleSetCompositionLanguage(style, 2);
    CTParagraphStyleSetCompositionLanguage(NULL, 1);
    CTTextAlignment read = 0;
    CTParagraphStyleGetValueForSpecifier(centered, kCTParagraphStyleSpecifierAlignment, sizeof(read), &read);
    CHECK(read == kCTTextAlignmentCenter, "setting the composition language leaves the other settings alone");
    CFRelease(style); CFRelease(centered);
    CFRelease(smallAttrs); CFRelease(largeAttrs); CFRelease(small); CFRelease(large);
    printf("RESULT failures=%d\n", failures);
    return failures ? 1 : 0;
} }
