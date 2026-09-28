#import <Foundation/Foundation.h>
#import <CoreText/CTFont.h>
#import <AppKit/AppKitExport.h>

@class UTType;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

APPKIT_EXPORT NSAttributedStringKey const NSAdaptiveImageGlyphAttributeName NS_SWIFT_NAME(adaptiveImageGlyph);

// Matches Apple's declaration member for member, since Clang rejects a class two modules define differently.
// The metadata members raise: Apple does not document the content format (VibeDarling/darling#845).
NS_SWIFT_SENDABLE
@interface NSAdaptiveImageGlyph : NSObject <NSCopying, NSSecureCoding, CTAdaptiveImageProviding>
#if !__OBJC2__
{
    NSData *_imageContent;
}
#endif

- (instancetype)initWithImageContent:(NSData *)imageContent NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly) NSData *imageContent;
@property (readonly) NSString *contentIdentifier;
@property (readonly, copy) NSString *contentDescription;

@property (class, readonly) UTType *contentType;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
