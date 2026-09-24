/* Copyright (c) 2008 Johannes Fortmann

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE. */

#import <CoreText/KTFont_FT.h>
#import <Onyx2D/O2Font_freetype.h>
#import <Onyx2D/O2MutablePath.h>

@implementation KTFont (KTFont_FT)
+ (id) allocWithZone: (NSZone *) zone {
    return NSAllocateObject([KTFont_FT class], 0, NULL);
}
@end

typedef struct {
    O2MutablePathRef path;
    const O2AffineTransform *matrix;
    BOOL contourOpen;
} KTGlyphPathBuilder;

static int glyphPathMoveTo(const FT_Vector *to, void *user) {
    KTGlyphPathBuilder *builder = user;

    if (builder->contourOpen)
        O2PathCloseSubpath(builder->path);
    O2PathMoveToPoint(builder->path, builder->matrix, to->x, to->y);
    builder->contourOpen = YES;
    return 0;
}

static int glyphPathLineTo(const FT_Vector *to, void *user) {
    KTGlyphPathBuilder *builder = user;

    O2PathAddLineToPoint(builder->path, builder->matrix, to->x, to->y);
    return 0;
}

static int glyphPathConicTo(const FT_Vector *control, const FT_Vector *to,
                            void *user)
{
    KTGlyphPathBuilder *builder = user;

    O2PathAddQuadCurveToPoint(builder->path, builder->matrix, control->x,
                              control->y, to->x, to->y);
    return 0;
}

static int glyphPathCubicTo(const FT_Vector *control1,
                            const FT_Vector *control2, const FT_Vector *to,
                            void *user)
{
    KTGlyphPathBuilder *builder = user;

    O2PathAddCurveToPoint(builder->path, builder->matrix, control1->x,
                          control1->y, control2->x, control2->y, to->x, to->y);
    return 0;
}

@implementation KTFont_FT

- (CGPathRef) createPathForGlyph: (CGGlyph) glyph
                       transform: (CGAffineTransform *) xform
{
    FT_Face face = [(O2Font_freetype *) _font face];

    // Unscaled outlines are in font units, so the shared face's size is left alone.
    if (FT_Load_Glyph(face, glyph, FT_LOAD_NO_SCALE) != 0 ||
        face->glyph->format != FT_GLYPH_FORMAT_OUTLINE)
        return NULL;

    O2Float scale = _size / face->units_per_EM;
    O2AffineTransform matrix = O2AffineTransformMakeScale(scale, scale);
    if (xform != NULL) {
        O2AffineTransform append = {xform->a,  xform->b,  xform->c,
                                    xform->d,  xform->tx, xform->ty};
        matrix = O2AffineTransformConcat(matrix, append);
    }

    KTGlyphPathBuilder builder = {O2PathCreateMutable(), &matrix, NO};
    const FT_Outline_Funcs funcs = {glyphPathMoveTo, glyphPathLineTo,
                                    glyphPathConicTo, glyphPathCubicTo, 0, 0};

    if (FT_Outline_Decompose(&face->glyph->outline, &funcs, &builder) != 0) {
        O2PathRelease(builder.path);
        return NULL;
    }
    if (builder.contourOpen)
        O2PathCloseSubpath(builder.path);
    return (CGPathRef) builder.path;
}

- initWithUIFontType: (CTFontUIFontType) uiFontType
                size: (CGFloat) size
            language: (NSString *) language
{
    O2Font *font = nil;

    switch (uiFontType) {

    case kCTFontMenuTitleFontType:
    case kCTFontMenuItemFontType:
        if (size == 0)
            size = 12;
        font = O2FontCreateWithFontName(@"San Francisco");
        break;

    default:
        return nil;
    }

    self = [self initWithFont: (CGFontRef)font size: size];

    [font release];

    return self;
}

- (void) getGlyphs: (CGGlyph *) glyphs
        forCharacters: (const unichar *) characters
               length: (NSUInteger) length
{
    O2Font_freetype *o2Font = (O2Font_freetype *) _font;
    FT_Face face = [o2Font face];

    int i;
    for (i = 0; i < length; i++) {
        glyphs[i] = FT_Get_Char_Index(face, characters[i]);
    }
}

- (void) getAdvancements: (CGSize *) advancements
               forGlyphs: (const CGGlyph *) glyphs
                   count: (NSUInteger) count
{
    O2Font_freetype *o2Font = (O2Font_freetype *) _font;
    FT_Face face = [o2Font face];

    int i;
    FT_Set_Pixel_Sizes(face, _size, _size);

    for (i = 0; i < count; i++) {
        FT_Load_Glyph(face, glyphs[i], FT_LOAD_DEFAULT);
        advancements[i] = CGSizeMake(face->glyph->advance.x / (O2Float)(2 << 5),
                       face->glyph->advance.y / (O2Float)(2 << 5));
    }
}

- (CGPoint) positionOfGlyph: (CGGlyph) current
            precededByGlyph: (CGGlyph) previous
                  isNominal: (BOOL *) isNominalp
{
    O2Font_freetype *o2Font = (O2Font_freetype *) _font;
    FT_Face face = [o2Font face];

    *isNominalp = YES;

    if (!current)
        return NSZeroPoint;

    FT_Set_Pixel_Sizes(face, _size, _size);

    FT_Load_Glyph(face, current, FT_LOAD_DEFAULT);
    return NSMakePoint(face->glyph->advance.x / (O2Float)(2 << 5),
                       face->glyph->advance.y / (O2Float)(2 << 5));
}

@end
