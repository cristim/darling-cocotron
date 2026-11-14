#import <AppKit/AppKit.h>
#include <stdlib.h>
#include <string.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSString *raisedName(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [exception name];
    }
    return nil;
}

// Renders the fragment into an RGBA bitmap and returns its bytes; nil context state is the caller's business.
static NSData *render(NSTextLineFragment *fragment)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    size_t width = 160, height = 80;
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGContextRef context = CGBitmapContextCreate([data mutableBytes], width, height, 8, width * 4, space,
                                                 kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    [fragment drawAtPoint:CGPointMake(4, 4) inContext:context];
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return data;
}

static BOOL hasInk(NSData *data)
{
    const unsigned char *bytes = [data bytes];
    for (NSUInteger i = 3; i < [data length]; i += 4)
        if (bytes[i] != 0)
            return YES;
    return NO;
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

    // Characters that are not one glyph each: a surrogate pair and a combining mark. A character that has a glyph is
    // not at the end of the line.
    for (NSString *text in @[ @"a\U0001F600b", @"e\u0301b" ]) {
        NSUInteger last = [text length] - 1;
        NSTextLineFragment *wide = [[[NSTextLineFragment alloc] initWithString:text attributes:attributes
                                                                         range:NSMakeRange(0, [text length])] autorelease];
        CGPoint atLast = [wide locationForCharacterAtIndex:last];
        CGPoint atEnd = [wide locationForCharacterAtIndex:[text length]];
        expect(atLast.x < atEnd.x && atLast.x > [wide locationForCharacterAtIndex:0].x,
               [NSString stringWithFormat:@"GUESS: the last character of %@ is before the end of the line, not at it", text]);
        expect(fabs(atEnd.x - wide.typographicBounds.size.width) < 0.01,
               @"GUESS: the end of the string is at the right edge of the typographic bounds");
    }

    // A range with a line break: only its first line is measured, drawn and addressed.
    NSAttributedString *twoLines = [[[NSAttributedString alloc] initWithString:@"ab\ncd" attributes:attributes] autorelease];
    NSTextLineFragment *two = [[[NSTextLineFragment alloc] initWithAttributedString:twoLines range:NSMakeRange(0, 5)] autorelease];
    NSTextLineFragment *one = [[[NSTextLineFragment alloc] initWithString:@"ab" attributes:attributes range:NSMakeRange(0, 2)] autorelease];
    expect(NSEqualRanges(two.characterRange, NSMakeRange(0, 5)), @"the character range is the whole range");
    expect(two.typographicBounds.size.height == one.typographicBounds.size.height &&
               two.typographicBounds.size.width == one.typographicBounds.size.width,
           @"GUESS: a range with a line break has the bounds of its first line");
    expect([raisedName(^{ [two locationForCharacterAtIndex:4]; }) isEqual:NSRangeException],
           @"GUESS: a character on a later line raises NSRangeException");
    expect([two characterIndexForPoint:CGPointMake(10000, 3)] == 1 && [two characterIndexForPoint:CGPointMake(-5, 3)] == 0,
           @"GUESS: the far right of a first line ending in a break is its last character, not the break");
    NSData *twoInk = render(two), *oneInk = render(one);
    expect(hasInk(oneInk), @"drawing a line puts ink in the bitmap");
    expect([twoInk isEqualToData:oneInk], @"GUESS: drawing a range with a line break draws only its first line");

    // drawAtPoint:inContext: leaves the current graphics context as it found it, none included.
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef scratch = CGBitmapContextCreate(NULL, 8, 8, 8, 32, space, kCGImageAlphaPremultipliedLast);
    [NSGraphicsContext setCurrentContext:nil];
    [one drawAtPoint:CGPointMake(4, 4) inContext:scratch];
    expect([NSGraphicsContext currentContext] == nil, @"GUESS: with no current graphics context, none is current after drawing");
    NSGraphicsContext *other = [NSGraphicsContext graphicsContextWithCGContext:scratch flipped:NO];
    [NSGraphicsContext setCurrentContext:other];
    [one drawAtPoint:CGPointMake(4, 4) inContext:scratch];
    expect([NSGraphicsContext currentContext] == other, @"GUESS: the previous current graphics context is current after drawing");
    [NSGraphicsContext setCurrentContext:nil];
    CGContextRelease(scratch);
    CGColorSpaceRelease(space);

    [pool drain];
    printf("PASS: NSTextLineFragment\n");
    return 0;
}
