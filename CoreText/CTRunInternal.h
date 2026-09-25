#import <Foundation/Foundation.h>
#import <CoreText/CTRun.h>
#import <CoreText/CTFont.h>

@interface _CTRun : NSObject {
@public
    NSDictionary *_attributes;
    CTFontRef _font;
    CFRange _stringRange;
    CFIndex _count;
    CGGlyph *_glyphs;
    CGPoint *_positions;
    CGSize *_advances;
    CFIndex *_indices;
    double _width;
}
- (id)initWithString:(NSString *)string attributes:(NSDictionary *)attributes
              range:(NSRange)range origin:(double)origin;
@end
