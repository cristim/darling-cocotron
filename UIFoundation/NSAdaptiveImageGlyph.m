#import <AppKit/NSAdaptiveImageGlyph.h>
#import "CTAdaptiveImageGlyph.h"

// Local values, not Apple's (undocumented): both appear in archives written here.
NSAttributedStringKey const NSAdaptiveImageGlyphAttributeName = @"NSAdaptiveImageGlyph";
static NSString *const NSAdaptiveImageGlyphImageContentKey = @"NSAdaptiveImageGlyphImageContent";

static void raiseUndocumentedContent(char kind, SEL selector)
{
    [NSException raise:NSInternalInconsistencyException
                format:@"%c[NSAdaptiveImageGlyph %@]: Darling cannot read adaptive image glyph content, whose format "
                       @"Apple does not document (VibeDarling/darling#845)",
                       kind, NSStringFromSelector(selector)];
}

@interface NSAdaptiveImageGlyph ()
- (instancetype)initWithCTAdaptiveImageGlyph:(CTAdaptiveImageGlyph *)adaptiveImageGlyph;
@end

@implementation NSAdaptiveImageGlyph
#if __OBJC2__
{
    NSData *_imageContent;
}
#endif

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (UTType *)contentType
{
    raiseUndocumentedContent('+', _cmd);
    return nil;
}

- (instancetype)init
{
    [self release];
    [NSException raise:NSInvalidArgumentException format:@"-[NSAdaptiveImageGlyph init]: use initWithImageContent:"];
    return nil;
}

- (instancetype)initWithImageContent:(NSData *)imageContent
{
    if (imageContent == nil)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"-[NSAdaptiveImageGlyph initWithImageContent:]: nil image content"];
    }
    self = [super init];
    if (self != nil)
        _imageContent = [imageContent copy];
    return self;
}

- (instancetype)initWithCTAdaptiveImageGlyph:(CTAdaptiveImageGlyph *)adaptiveImageGlyph
{
    return [self initWithImageContent:adaptiveImageGlyph.imageContent];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"NSAdaptiveImageGlyph supports only keyed coding"];
    }
    NSData *imageContent = [coder decodeObjectOfClass:[NSData class] forKey:NSAdaptiveImageGlyphImageContentKey];
    if (![imageContent isKindOfClass:[NSData class]])
    {
        [self release];
        return nil;
    }
    self = [super init];
    if (self != nil)
        _imageContent = [imageContent copy];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
        [NSException raise:NSInvalidArgumentException format:@"NSAdaptiveImageGlyph supports only keyed coding"];
    [coder encodeObject:_imageContent forKey:NSAdaptiveImageGlyphImageContentKey];
}

- (void)dealloc
{
    [_imageContent release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (NSData *)imageContent
{
    return _imageContent;
}

- (NSString *)contentIdentifier
{
    raiseUndocumentedContent('-', _cmd);
    return nil;
}

- (NSString *)contentDescription
{
    raiseUndocumentedContent('-', _cmd);
    return nil;
}

- (CGImageRef)imageForProposedSize:(CGSize)proposedSize
                       scaleFactor:(CGFloat)scaleFactor
                       imageOffset:(CGPoint *)outImageOffset
                         imageSize:(CGSize *)outImageSize
{
    raiseUndocumentedContent('-', _cmd);
    return NULL;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    return [other isKindOfClass:[NSAdaptiveImageGlyph class]] &&
           [_imageContent isEqualToData:((NSAdaptiveImageGlyph *)other)->_imageContent];
}

- (NSUInteger)hash
{
    return [_imageContent hash];
}

@end
