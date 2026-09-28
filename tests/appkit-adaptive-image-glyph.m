#import <AppKit/AppKit.h>
#import "../CoreText/CTAdaptiveImageGlyph.h"
#include <stdlib.h>

// Private initializer that clients such as OpenSwiftUI declare themselves.
@interface NSAdaptiveImageGlyph (CTAdaptiveImageGlyph)
- (instancetype)initWithCTAdaptiveImageGlyph:(CTAdaptiveImageGlyph *)adaptiveImageGlyph;
@end

// Archives under NSAdaptiveImageGlyph's key whatever it is given, to feed the decoder bad input.
@interface ForgedGlyph : NSObject <NSCoding>
{
    id _value;
}
- (instancetype)initWithValue:(id)value;
@end

@implementation ForgedGlyph
- (instancetype)initWithValue:(id)value
{
    self = [super init];
    _value = [value retain];
    return self;
}
- (void)dealloc
{
    [_value release];
    [super dealloc];
}
- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithValue:nil];
}
- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_value != nil)
        [coder encodeObject:_value forKey:@"NSAdaptiveImageGlyphImageContent"];
}
@end

static id decodeForged(id value)
{
    ForgedGlyph *forged = [[[ForgedGlyph alloc] initWithValue:value] autorelease];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:forged];
    NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:data] autorelease];
    [unarchiver setClass:[NSAdaptiveImageGlyph class] forClassName:@"ForgedGlyph"];
    return [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
}

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSException *exceptionFrom(void (^block)(void))
{
    @try
    {
        block();
    }
    @catch (NSException *exception)
    {
        return exception;
    }
    return nil;
}

static BOOL namesIssue(NSException *exception)
{
    return [exception.name isEqualToString:NSInternalInconsistencyException] &&
           [exception.reason rangeOfString:@"VibeDarling/darling#845"].location != NSNotFound;
}

int main(void)
{
    @autoreleasepool
    {
        const char bytes[] = "\0\0\0\x18" "ftypheic";
        NSData *content = [NSData dataWithBytes:bytes length:sizeof(bytes) - 1];
        NSMutableData *source = [[content mutableCopy] autorelease];
        NSAdaptiveImageGlyph *glyph = [[[NSAdaptiveImageGlyph alloc] initWithImageContent:source] autorelease];
        expect([glyph.imageContent isEqualToData:content], @"image content round trip");
        [source appendBytes:"x" length:1];
        expect([glyph.imageContent isEqualToData:content], @"image content is copied");
        expect([glyph conformsToProtocol:@protocol(CTAdaptiveImageProviding)], @"conforms to CTAdaptiveImageProviding");
        expect([NSAdaptiveImageGlyph supportsSecureCoding], @"supports secure coding");
        NSAdaptiveImageGlyph *copy = [glyph copy];
        expect(copy == glyph, @"immutable copy is the same object");
        [copy release];

        NSAdaptiveImageGlyph *same = [[[NSAdaptiveImageGlyph alloc] initWithImageContent:content] autorelease];
        NSAdaptiveImageGlyph *other = [[[NSAdaptiveImageGlyph alloc] initWithImageContent:source] autorelease];
        expect([glyph isEqual:same] && glyph.hash == same.hash, @"equal content, equal glyphs and hashes");
        expect(![glyph isEqual:other], @"different content, different glyphs");

        NSData *none = nil;
        expect(exceptionFrom(^{ [[NSAdaptiveImageGlyph alloc] initWithImageContent:none]; }) != nil, @"nil content raises");

        CTAdaptiveImageGlyph *ctGlyph = [[[CTAdaptiveImageGlyph alloc] initWithImageContent:content] autorelease];
        NSAdaptiveImageGlyph *fromCT = [[[NSAdaptiveImageGlyph alloc] initWithCTAdaptiveImageGlyph:ctGlyph] autorelease];
        expect([fromCT isEqual:glyph], @"conversion from CTAdaptiveImageGlyph keeps the content");

        NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initRequiringSecureCoding:YES] autorelease];
        [archiver encodeObject:glyph forKey:NSKeyedArchiveRootObjectKey];
        [archiver finishEncoding];
        NSError *error = nil;
        NSAdaptiveImageGlyph *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSAdaptiveImageGlyph class]
                                                                          fromData:archiver.encodedData
                                                                             error:&error];
        expect(decoded != nil && error == nil, @"secure unarchive succeeds");
        expect([decoded isEqual:glyph], @"secure coding round trip");

        expect([decodeForged(content) isEqual:glyph], @"non-secure unarchive of the forged archive's data");
        expect(decodeForged(@"not data") == nil, @"non-secure unarchive rejects content of the wrong class");
        expect(decodeForged(nil) == nil, @"unarchive rejects a missing content key");
        expect(exceptionFrom(^{ [[NSAdaptiveImageGlyph alloc] performSelector:@selector(init)]; }) != nil,
               @"init without content raises");

        NSAttributedString *text = [[[NSAttributedString alloc]
            initWithString:@"\uFFFC"
                attributes:@{NSAdaptiveImageGlyphAttributeName : glyph}] autorelease];
        expect([[text attribute:NSAdaptiveImageGlyphAttributeName atIndex:0 effectiveRange:NULL] isEqual:glyph],
               @"glyph as an attributed string attribute");

        expect(namesIssue(exceptionFrom(^{ (void)glyph.contentIdentifier; })), @"contentIdentifier raises");
        expect(namesIssue(exceptionFrom(^{ (void)glyph.contentDescription; })), @"contentDescription raises");
        expect(namesIssue(exceptionFrom(^{ (void)NSAdaptiveImageGlyph.contentType; })), @"contentType raises");
        expect(namesIssue(exceptionFrom(^{
                   CGPoint offset;
                   CGSize size;
                   [glyph imageForProposedSize:CGSizeMake(20, 20) scaleFactor:2 imageOffset:&offset imageSize:&size];
               })),
               @"image lookup raises");
    }
    NSLog(@"PASS");
    return 0;
}
