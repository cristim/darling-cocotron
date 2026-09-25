#import <CoreText/CTLine.h>
#import <CoreText/CTRun.h>
#import <Foundation/Foundation.h>
#import "CTRunInternal.h"

@interface _CTLine : NSObject {
@public
    NSAttributedString *_string;
    NSArray *_runs;
}
@end

@implementation _CTLine
- (void)dealloc {
    [_string release];
    [_runs release];
    [super dealloc];
}
@end

CFTypeID CTLineGetTypeID(void) { return (CFTypeID)[_CTLine self]; }

CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef attrString) {
    if (!attrString) return NULL;
    _CTLine *line = [[_CTLine alloc] init];
    line->_string = [(NSAttributedString *)attrString copy];
    NSMutableArray *runs = [[NSMutableArray alloc] init];
    NSString *string = [line->_string string];
    NSUInteger length = [string length];
    double origin = 0;
    for (NSUInteger index = 0; index < length;) {
        NSRange range;
        NSDictionary *attributes = [line->_string attributesAtIndex:index effectiveRange:&range];
        if (!range.length || range.location > index) break;
        if (range.location < index) {
            range.length -= index - range.location;
            range.location = index;
        }
        _CTRun *run = [[_CTRun alloc] initWithString:string attributes:attributes
                                              range:range origin:origin];
        if (run) {
            [runs addObject:run];
            origin += run->_width;
        }
        [run release];
        index = NSMaxRange(range);
    }
    line->_runs = runs;
    return (CTLineRef)line;
}

CTLineRef CTLineCreateTruncatedLine(CTLineRef line, double width,
                                   CTLineTruncationType truncationType,
                                   CTLineRef truncationToken) {
    return NULL;
}

CTLineRef CTLineCreateJustifiedLine(CTLineRef line, CGFloat justificationFactor,
                                   double justificationWidth) {
    return NULL;
}

CFIndex CTLineGetGlyphCount(CTLineRef line) {
    if (!line) return 0;
    CFIndex count = 0;
    for (_CTRun *run in ((_CTLine *)line)->_runs) count += run->_count;
    return count;
}

CFArrayRef CTLineGetGlyphRuns(CTLineRef line) {
    return line ? (CFArrayRef)((_CTLine *)line)->_runs : NULL;
}

CFRange CTLineGetStringRange(CTLineRef line) {
    return CFRangeMake(0, line ? [((_CTLine *)line)->_string length] : 0);
}

double CTLineGetTypographicBounds(CTLineRef line, CGFloat *ascent,
                                  CGFloat *descent, CGFloat *leading) {
    if (ascent) *ascent = 0;
    if (descent) *descent = 0;
    if (leading) *leading = 0;
    if (!line) return 0;
    double width = 0;
    for (_CTRun *run in ((_CTLine *)line)->_runs) {
        width += run->_width;
        CGFloat a = CTFontGetAscent(run->_font);
        CGFloat d = CTFontGetDescent(run->_font);
        CGFloat l = CTFontGetLeading(run->_font);
        if (ascent && a > *ascent) *ascent = a;
        if (descent && d > *descent) *descent = d;
        if (leading && l > *leading) *leading = l;
    }
    return width;
}

double CTLineGetPenOffsetForFlush(CTLineRef line, CGFloat flushFactor, double flushWidth) {
    return (flushWidth - CTLineGetTypographicBounds(line, NULL, NULL, NULL)) * flushFactor;
}

void CTLineDraw(CTLineRef line, CGContextRef context) {
    if (!line || !context) return;
    for (_CTRun *run in ((_CTLine *)line)->_runs)
        CTRunDraw((CTRunRef)run, context, CFRangeMake(0, 0));
}

CGRect CTLineGetBoundsWithOptions(CTLineRef line, CTLineBoundsOptions options) {
    CGFloat ascent = 0, descent = 0;
    double width = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
    return CGRectMake(0, -descent, width, ascent + descent);
}

double CTLineGetTrailingWhitespaceWidth(CTLineRef line) { return 0; }
CGRect CTLineGetImageBounds(CTLineRef line, CGContextRef context) {
    return CTLineGetBoundsWithOptions(line, 0);
}

CFIndex CTLineGetStringIndexForPosition(CTLineRef line, CGPoint position) {
    if (!line) return kCFNotFound;
    if (position.x <= 0) return 0;
    for (_CTRun *run in ((_CTLine *)line)->_runs)
        for (CFIndex index = 0; index < run->_count; ++index)
            if (position.x < run->_positions[index].x + run->_advances[index].width / 2)
                return run->_indices[index];
    return [((_CTLine *)line)->_string length];
}

CGFloat CTLineGetOffsetForStringIndex(CTLineRef line, CFIndex charIndex,
                                     CGFloat *secondaryOffset) {
    CGFloat offset = 0;
    if (line) for (_CTRun *run in ((_CTLine *)line)->_runs) {
        for (CFIndex index = 0; index < run->_count; ++index)
            if (run->_indices[index] >= charIndex) {
                offset = run->_positions[index].x;
                if (secondaryOffset) *secondaryOffset = offset;
                return offset;
            }
        offset += run->_width;
    }
    if (secondaryOffset) *secondaryOffset = offset;
    return offset;
}
