/* Copyright (c) 2006-2008 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#import <CoreText/KTFont.h>
#import <Foundation/NSArray.h>
#import <Onyx2D/O2Exceptions.h>

@implementation KTFont

- initWithFont: (CGFontRef) font size: (CGFloat) size {
    _font = CGFontRetain(font);
    _unitsPerEm = CGFontGetUnitsPerEm(_font);
    _size = size;
    return self;
}

- initWithUIFontType: (CTFontUIFontType) uiFontType
                size: (CGFloat) size
            language: (NSString *) language
{
    O2InvalidAbstractInvocation();
    return nil;
}

- (void) dealloc {
    CGFontRelease(_font);
    [super dealloc];
}

- (CFStringRef) copyName {
    return CGFontCopyFullName(_font);
}

- (CGFontRef) copyGraphicsFont {
    return CGFontRetain(_font);
}

/* CTFont and NSFont share these identity operations on Quartz fonts. */
- (id) printerFont {
    return self;
}

- (id) screenFont {
    return self;
}

- (NSString *) fontName {
    return [(id)CTFontCopyPostScriptName((CTFontRef)self) autorelease];
}

- (NSString *) familyName {
    return [(id)CTFontCopyFamilyName((CTFontRef)self) autorelease];
}

- (CGFloat) pointSize {
    return _size;
}

- (CGFloat) fontSize {
    return _size;
}

- (CGRect) boundingRect {
    CGRect box = CGFontGetFontBBox(_font);
    if (_unitsPerEm == 0)
        return CGRectZero;
    CGFloat scale = _size / _unitsPerEm;
    return CGRectMake(box.origin.x * scale, box.origin.y * scale,
                      box.size.width * scale, box.size.height * scale);
}

- (CGFloat) ascender {
    CGFloat ascent = CGFontGetAscent(_font);

    return (ascent / _unitsPerEm) * _size;
}

// CT descenter is the opposite of the CG one on Cocoa
- (CGFloat) descender {
    CGFloat descent = CGFontGetDescent(_font);
    return -(descent / _unitsPerEm) * _size;
}

- (CGFloat) leading {
    CGFloat leading = CGFontGetLeading(_font);

    return (leading / _unitsPerEm) * _size;
}

- (CGFloat) underlineThickness {
    /* FreeType's generic CGFont bridge does not expose underline metrics.
     * Use the conventional em-relative values expected by CoreText clients. */
    return _size / 14.0;
}

- (CGFloat) underlinePosition {
    return -_size / 10.0;
}

- (CGFloat) italicAngle {
    return CGFontGetItalicAngle(_font);
}

- (CGFloat) xHeight {
    CGFloat xHeight = CGFontGetXHeight(_font);

    return (xHeight / _unitsPerEm) * _size;
}

- (CGFloat) capHeight {
    CGFloat capHeight = CGFontGetCapHeight(_font);

    return (capHeight / _unitsPerEm) * _size;
}

- (NSUInteger) numberOfGlyphs {
    return CGFontGetNumberOfGlyphs(_font);
}

- (CGPoint) positionOfGlyph: (CGGlyph) current
            precededByGlyph: (CGGlyph) previous
                  isNominal: (BOOL *) isNominalp
{
    int advancement;

    if (previous == 0)
        return CGPointMake(0, 0);

    *isNominalp = YES;
    CGFontGetGlyphAdvances(_font, &previous, 1, &advancement);

    return CGPointMake(((CGFloat) advancement / _unitsPerEm) * _size, 0);
}

- (void) getGlyphs: (CGGlyph *) glyphs
        forCharacters: (const unichar *) characters
               length: (NSUInteger) length
{
    int i;

    for (i = 0; i < length; i++) {
        uint16_t code = characters[i];
        uint8_t group = code >> 8;
        uint8_t index = code & 0xFF;

        if (_twoLevel[group] == NULL)
            glyphs[i] = 0;
        else
            glyphs[i] = _twoLevel[group][index];
    }
}

- (void) getAdvancements: (CGSize *) advancements
               forGlyphs: (const CGGlyph *) glyphs
                   count: (NSUInteger) count
{
    int advances[count];

    CGFontGetGlyphAdvances(_font, glyphs, count, advances);
    for (int i = 0; i < count; i++) {
        advancements[i].width =
                ((CGFloat) advances[i] / (CGFloat) _unitsPerEm) * _size;
        advancements[i].height = 0;
    }
}

- (CGPathRef) createPathForGlyph: (CGGlyph) glyph
                       transform: (CGAffineTransform *) xform
{
    /* Keep the CoreText Copy contract even where the generic backend cannot
     * yet expose a native outline. An empty retained path is a valid glyph
     * path (e.g. for whitespace) and lets clients fall back to table-based
     * outline extraction instead of throwing an Objective-C exception. */
    (void)glyph;
    (void)xform;
    return CGPathCreateMutable();
}

@end
