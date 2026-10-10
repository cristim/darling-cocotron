#import <AppKit/AppKit.h>
#include <math.h>
#include <stdio.h>

// A selection boundary splits a line fragment into separately drawn runs. Each
// run must start where the preceding glyphs end, not one glyph further on.
// Hooks Cocotron's own per-run draw method to record where each run starts.
@interface NSLayoutManager (RunDrawing)
- (void)_drawGlyphs:(NSGlyph *)glyphs length:(NSUInteger)length range:(NSRange)range
            atPoint:(NSPoint)point inContainer:(NSTextContainer *)container
     withAttributes:(NSDictionary *)attributes origin:(NSPoint)origin;
@end

@interface RecordingLayoutManager : NSLayoutManager
@property (retain) NSMutableDictionary *runX;
@end
@implementation RecordingLayoutManager
- (void)_drawGlyphs:(NSGlyph *)glyphs length:(NSUInteger)length range:(NSRange)range
            atPoint:(NSPoint)point inContainer:(NSTextContainer *)container
     withAttributes:(NSDictionary *)attributes origin:(NSPoint)origin {
    self.runX[@(range.location)] = @(point.x);
}
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSFont *font = [NSFont systemFontOfSize:20];
        // Distinct widths make an off-by-one-glyph advance visible.
        // Cocotron's concrete NSTextStorage has no initWithString:attributes:.
        NSTextStorage *storage = [[NSTextStorage alloc] initWithString:@"WWiiWW"];
        [storage setAttributes:@{NSFontAttributeName : font} range:NSMakeRange(0, 6)];
        RecordingLayoutManager *lm = [RecordingLayoutManager new];
        lm.runX = [NSMutableDictionary dictionary];
        [storage addLayoutManager:lm];
        NSTextContainer *tc = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(1000, 100)];
        [lm addTextContainer:tc];
        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 100)
                                               textContainer:tc];
        [view setSelectedRange:NSMakeRange(2, 2)];

        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
            pixelsWide:1000 pixelsHigh:100 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
            isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
        [lm drawGlyphsForGlyphRange:[lm glyphRangeForTextContainer:tc] atPoint:NSZeroPoint];

        NSNumber *start = lm.runX[@0], *selected = lm.runX[@2];
        if (start == nil || selected == nil) {
            fprintf(stderr, "FAIL: expected runs at 0 and 2, got %s\n",
                    [[lm.runX description] UTF8String]);
            return 1;
        }
        NSGlyph glyphs[2];
        [lm getGlyphs:glyphs range:NSMakeRange(0, 2)];
        CGFloat expected = [font advancementForGlyph:glyphs[0]].width +
                           [font advancementForGlyph:glyphs[1]].width;
        CGFloat actual = [selected doubleValue] - [start doubleValue];
        if (fabs(actual - expected) > 0.01) {
            fprintf(stderr, "FAIL: selected run starts at +%.2f, expected +%.2f\n",
                    actual, expected);
            return 1;
        }
        puts("PASS: a selection-split run starts after the preceding glyphs");
    }
    return 0;
}
