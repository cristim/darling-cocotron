#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

// GUESS (not in the public documentation, not observed): every coordinate convention below, as listed in
// UIFoundation/NSTextLineFragment.m. The EXPECT messages that start with GUESS are those.
int main(void)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    expect(NSClassFromString(@"NSTextLineFragment") != Nil, @"the class exists");

    NSFont *font = [NSFont systemFontOfSize:14];
    NSDictionary *attributes = @{NSFontAttributeName : font};
    NSTextLineFragment *line = [[[NSTextLineFragment alloc] initWithString:@"Hello, world" attributes:attributes
                                                                     range:NSMakeRange(0, 12)] autorelease];
    expect([line.attributedString.string isEqual:@"Hello, world"], @"the attributed string is the source string");
    expect(NSEqualRanges(line.characterRange, NSMakeRange(0, 12)), @"the character range is the range");

    CGRect bounds = line.typographicBounds;
    expect(bounds.origin.x == 0 && bounds.origin.y == 0, @"GUESS: typographicBounds starts at the line's top left");
    expect(bounds.size.width > 20 && bounds.size.height > 8, @"GUESS: typographicBounds has the size of the laid out line");
    expect(line.glyphOrigin.x == 0 && line.glyphOrigin.y > 0 && line.glyphOrigin.y <= bounds.size.height,
           @"GUESS: glyphOrigin is the baseline origin of the first glyph, inside the line");

    NSTextLineFragment *sub = [[[NSTextLineFragment alloc] initWithAttributedString:line.attributedString
                                                                              range:NSMakeRange(7, 5)] autorelease];
    expect(NSEqualRanges(sub.characterRange, NSMakeRange(7, 5)) && [sub.attributedString isEqual:line.attributedString],
           @"a sub range keeps the whole source string");
    expect(sub.typographicBounds.size.width < bounds.size.width, @"GUESS: only the range is laid out");

    CGPoint at0 = [line locationForCharacterAtIndex:0];
    CGPoint at5 = [line locationForCharacterAtIndex:5];
    CGPoint end = [line locationForCharacterAtIndex:12];
    expect(at0.x == 0 && at0.y == line.glyphOrigin.y, @"GUESS: the first character is at the glyph origin");
    expect(at5.x > at0.x && end.x > at5.x && at5.y == at0.y, @"GUESS: locations advance along the baseline");
    CGPoint subStart = [sub locationForCharacterAtIndex:7];
    expect(subStart.x == 0, @"GUESS: location indexes are into the source string, the range start is at x 0");

    expect([line characterIndexForPoint:CGPointMake(-50, 3)] == 0, @"GUESS: a point before the line is the first character");
    expect([line characterIndexForPoint:CGPointMake(at5.x + 1, 3)] == 5, @"GUESS: a point on a glyph is its character");
    expect([line characterIndexForPoint:CGPointMake(10000, 3)] == 11, @"GUESS: a point after the line is the last character");
    expect([sub characterIndexForPoint:CGPointMake(-50, 3)] == 7, @"GUESS: indexes of a sub range are source string indexes");
    CGFloat fraction = [line fractionOfDistanceThroughGlyphForPoint:CGPointMake(at5.x + 0.01, 3)];
    expect(fraction >= 0 && fraction < 0.5, @"GUESS: the fraction through a glyph is small at its left edge");

    BOOL raised = NO;
    @try {
        [line locationForCharacterAtIndex:40];
    } @catch (NSException *exception) {
        raised = [[exception name] isEqual:NSRangeException];
    }
    expect(raised, @"GUESS: an index outside the character range raises NSRangeException");
    raised = NO;
    @try {
        [[NSTextLineFragment alloc] initWithString:@"abc" attributes:attributes range:NSMakeRange(2, 5)];
    } @catch (NSException *exception) {
        raised = [[exception name] isEqual:NSRangeException];
    }
    expect(raised, @"GUESS: a range beyond the string raises NSRangeException");

    raised = NO;
    @try {
        [[NSTextLineFragment alloc] initWithCoder:nil];
    } @catch (NSException *exception) {
        raised = [[exception name] isEqual:NSInvalidArgumentException];
    }
    expect(raised, @"GUESS: initWithCoder: fails loudly");

    [pool drain];
    printf("PASS: NSTextLineFragment\n");
    return 0;
}
