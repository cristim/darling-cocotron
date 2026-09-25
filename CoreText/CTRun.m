#import <CoreText/CTRun.h>
#import <CoreText/CTFont.h>
#import <CoreText/CTStringAttributes.h>
#import <Foundation/Foundation.h>
#import "CTRunInternal.h"
#include <stdlib.h>
#include <string.h>

@implementation _CTRun
- (id)initWithString:(NSString *)string attributes:(NSDictionary *)attributes
              range:(NSRange)range origin:(double)origin {
    self = [super init];
    if (!self) return nil;
    _attributes = [attributes copy];
    _stringRange = CFRangeMake(range.location, range.length);
    _count = range.length;
    _font = (CTFontRef)[_attributes objectForKey:(NSString *)kCTFontAttributeName];
    if (_font) CFRetain(_font);
    else _font = CTFontCreateWithName(CFSTR("Helvetica"), 12, NULL);
    if (_count) {
        _glyphs = calloc(_count, sizeof(*_glyphs));
        _positions = calloc(_count, sizeof(*_positions));
        _advances = calloc(_count, sizeof(*_advances));
        _indices = calloc(_count, sizeof(*_indices));
        UniChar *characters = calloc(_count, sizeof(*characters));
        if (!_glyphs || !_positions || !_advances || !_indices || !characters) {
            free(characters);
            [self release];
            return nil;
        }
        [string getCharacters:characters range:range];
        if (_font) {
            CTFontGetGlyphsForCharacters(_font, characters, _glyphs, _count);
            CTFontGetAdvancesForGlyphs(_font, kCTFontOrientationHorizontal,
                                       _glyphs, _advances, _count);
        }
        double x = origin;
        for (CFIndex index = 0; index < _count; ++index) {
            _indices[index] = range.location + index;
            _positions[index] = CGPointMake(x, 0);
            if (_advances[index].width <= 0) _advances[index].width = 7;
            x += _advances[index].width;
        }
        _width = x - origin;
        free(characters);
    }
    return self;
}
- (void)dealloc {
    [_attributes release];
    if (_font) CFRelease(_font);
    free(_glyphs);
    free(_positions);
    free(_advances);
    free(_indices);
    [super dealloc];
}
@end

static CFRange clippedRange(_CTRun *run, CFRange range) {
    if (!run || range.location < 0 || range.location >= run->_count)
        return CFRangeMake(0, 0);
    if (range.length == 0 || range.length > run->_count - range.location)
        range.length = run->_count - range.location;
    return range;
}

CFTypeID CTRunGetTypeID(void) { return (CFTypeID)[_CTRun self]; }
CFIndex CTRunGetGlyphCount(CTRunRef run) { return run ? ((_CTRun *)run)->_count : 0; }
CFDictionaryRef CTRunGetAttributes(CTRunRef run) {
    return run ? (CFDictionaryRef)((_CTRun *)run)->_attributes : NULL;
}
CTRunStatus CTRunGetStatus(CTRunRef run) { return kCTRunStatusNoStatus; }

const CGGlyph *CTRunGetGlyphsPtr(CTRunRef run) { return run ? ((_CTRun *)run)->_glyphs : NULL; }
void CTRunGetGlyphs(CTRunRef run, CFRange range, CGGlyph *buffer) {
    range = clippedRange((_CTRun *)run, range);
    if (buffer && range.length) memcpy(buffer, ((_CTRun *)run)->_glyphs + range.location,
                                       range.length * sizeof(*buffer));
}

const CGPoint *CTRunGetPositionsPtr(CTRunRef run) { return run ? ((_CTRun *)run)->_positions : NULL; }
void CTRunGetPositions(CTRunRef run, CFRange range, CGPoint *buffer) {
    range = clippedRange((_CTRun *)run, range);
    if (buffer && range.length) memcpy(buffer, ((_CTRun *)run)->_positions + range.location,
                                       range.length * sizeof(*buffer));
}

const CGSize *CTRunGetAdvancesPtr(CTRunRef run) { return run ? ((_CTRun *)run)->_advances : NULL; }
void CTRunGetAdvances(CTRunRef run, CFRange range, CGSize *buffer) {
    range = clippedRange((_CTRun *)run, range);
    if (buffer && range.length) memcpy(buffer, ((_CTRun *)run)->_advances + range.location,
                                       range.length * sizeof(*buffer));
}

const CFIndex *CTRunGetStringIndicesPtr(CTRunRef run) { return run ? ((_CTRun *)run)->_indices : NULL; }
void CTRunGetStringIndices(CTRunRef run, CFRange range, CFIndex *buffer) {
    range = clippedRange((_CTRun *)run, range);
    if (buffer && range.length) memcpy(buffer, ((_CTRun *)run)->_indices + range.location,
                                       range.length * sizeof(*buffer));
}

CFRange CTRunGetStringRange(CTRunRef run) {
    return run ? ((_CTRun *)run)->_stringRange : CFRangeMake(0, 0);
}

double CTRunGetTypographicBounds(CTRunRef run, CFRange range,
                                 CGFloat *ascent, CGFloat *descent, CGFloat *leading) {
    _CTRun *r = (_CTRun *)run;
    if (ascent) *ascent = r && r->_font ? CTFontGetAscent(r->_font) : 0;
    if (descent) *descent = r && r->_font ? CTFontGetDescent(r->_font) : 0;
    if (leading) *leading = r && r->_font ? CTFontGetLeading(r->_font) : 0;
    range = clippedRange(r, range);
    double width = 0;
    for (CFIndex index = range.location; index < range.location + range.length; ++index)
        width += r->_advances[index].width;
    return width;
}

CGRect CTRunGetImageBounds(CTRunRef run, CGContextRef context, CFRange range) {
    range = clippedRange((_CTRun *)run, range);
    CGFloat ascent = 0, descent = 0;
    double width = CTRunGetTypographicBounds(run, range, &ascent, &descent, NULL);
    _CTRun *r = (_CTRun *)run;
    double x = r && range.length ? r->_positions[range.location].x : 0;
    return CGRectMake(x, -descent, width, ascent + descent);
}

CGAffineTransform CTRunGetTextMatrix(CTRunRef run) { return CGAffineTransformIdentity; }

void CTRunGetBaseAdvancesAndOrigins(CTRunRef run, CFRange range,
                                    CGSize *advancesBuffer, CGPoint *originsBuffer) {
    CTRunGetAdvances(run, range, advancesBuffer);
    CTRunGetPositions(run, range, originsBuffer);
}

void CTRunDraw(CTRunRef run, CGContextRef context, CFRange range) {
    _CTRun *r = (_CTRun *)run;
    range = clippedRange(r, range);
    if (!context || !r || !r->_font || !range.length) return;
    CGContextSetTextPosition(context, r->_positions[range.location].x,
                            r->_positions[range.location].y);
    CTFontDrawGlyphsWithAdvances(r->_font, r->_glyphs + range.location,
                                 r->_advances + range.location, range.length, context);
}
