
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/CAAction.h>
#import <QuartzCore/CATransform3D.h>

@class CAAnimation, CALayerContext, CALayer;

enum {
    kCALayerNotSizable = 0x00,
    kCALayerMinXMargin = 0x01,
    kCALayerWidthSizable = 0x02,
    kCALayerMaxXMargin = 0x04,
    kCALayerMinYMargin = 0x08,
    kCALayerHeightSizable = 0x10,
    kCALayerMaxYMargin = 0x20,
};

CA_EXPORT NSString *const kCAFilterLinear;
CA_EXPORT NSString *const kCAFilterNearest;
CA_EXPORT NSString *const kCAFilterTrilinear;

CA_EXPORT NSString *const kCAGravityResizeAspect;
CA_EXPORT NSString *const kCAGravityResizeAspectFill;

CA_EXPORT NSString *const kCAGravityCenter;
CA_EXPORT NSString *const kCAGravityTop;
CA_EXPORT NSString *const kCAGravityBottom;
CA_EXPORT NSString *const kCAGravityLeft;
CA_EXPORT NSString *const kCAGravityRight;
CA_EXPORT NSString *const kCAGravityTopLeft;
CA_EXPORT NSString *const kCAGravityTopRight;
CA_EXPORT NSString *const kCAGravityBottomLeft;
CA_EXPORT NSString *const kCAGravityBottomRight;
CA_EXPORT NSString *const kCAGravityResize;

CA_EXPORT NSString *const kCAOnOrderIn;
CA_EXPORT NSString *const kCAOnOrderOut;
CA_EXPORT NSString *const kCATransition;

CA_EXPORT NSString *const kCAContentsFormatRGBA8Uint;
CA_EXPORT NSString *const kCAContentsFormatRGBA16Float;
CA_EXPORT NSString *const kCAContentsFormatGray8Uint;

@protocol CALayerDelegate <NSObject>

@optional

- (void)displayLayer: (CALayer*)layer;

- (void)drawLayer: (CALayer*)layer
        inContext: (CGContextRef)ctx;

- (void)layerWillDraw: (CALayer*)layer;

- (void)layoutSublayersOfLayer: (CALayer*)layer;

- (id<CAAction>)actionForLayer: (CALayer*)layer
                        forKey: (NSString*)event;

@end

@interface CALayer : NSObject {
    CALayerContext *_context;
    CALayer *_superlayer;
    NSArray *_sublayers;
    id _delegate;
    CGPoint _anchorPoint;
    CGPoint _position;
    CGRect _bounds;
    CGFloat _opacity;
    BOOL _opaque;
    BOOL _geometryFlipped;
    id _contents;
    CATransform3D _transform;
    CATransform3D _sublayerTransform;
    NSString *_minificationFilter;
    NSString *_magnificationFilter;
    BOOL _needsDisplay;
    NSMutableDictionary *_animations;
    NSNumber *_textureId;

    /* darling-lol M57: additional layer properties Chromium relies on. */
    NSUInteger _autoresizingMask;
    BOOL _masksToBounds;
    CGFloat _cornerRadius;
    CGColorRef _backgroundColor;
    CGFloat _borderWidth;
    CGColorRef _borderColor;
    CGFloat _zPosition;
    BOOL _hidden;
    BOOL _doubleSided;
    BOOL _needsDisplayOnBoundsChange;
    BOOL _shouldRasterize;
    CGFloat _rasterizationScale;
    BOOL _allowsEdgeAntialiasing;
    BOOL _allowsGroupOpacity;
    BOOL _allowsGroupBlending;
    BOOL _allowsHitTesting;
    BOOL _drawsAsynchronously;
    CGFloat _contentsScale;
    NSString *_contentsGravity;
    CGRect _contentsRect;
    CGRect _contentsCenter;
    CGFloat _anchorPointZ;
    CGFloat _shadowOpacity;
    CGSize _shadowOffset;
    CGFloat _shadowRadius;
    CGColorRef _shadowColor;
    id _shadowPath;
    float _minificationFilterBias;
    unsigned int _edgeAntialiasingMask;
    NSArray *_filters;
    NSArray *_backgroundFilters;
    id _compositingFilter;
    NSDictionary *_style;
    NSArray *_actions;
}

+ layer;

@property(readonly) CALayer *superlayer;
@property(copy) NSArray *sublayers;
@property(assign) id<CALayerDelegate> delegate;
@property CGPoint anchorPoint;
@property CGPoint position;
@property CGRect bounds;
@property CGRect frame;
@property CGFloat opacity;
@property BOOL opaque;
@property BOOL geometryFlipped;
@property NSUInteger autoresizingMask;
@property BOOL masksToBounds;
@property CGFloat cornerRadius;
@property CGColorRef backgroundColor;
@property CGFloat borderWidth;
@property CGColorRef borderColor;
@property CGFloat zPosition;
@property BOOL hidden;
@property BOOL doubleSided;
@property BOOL needsDisplayOnBoundsChange;
@property BOOL shouldRasterize;
@property CGFloat rasterizationScale;
@property BOOL allowsEdgeAntialiasing;
@property BOOL allowsGroupOpacity;
@property BOOL allowsGroupBlending;
@property BOOL allowsHitTesting;
@property BOOL drawsAsynchronously;
@property CGFloat contentsScale;
@property(copy) NSString *contentsGravity;
@property CGRect contentsRect;
@property CGRect contentsCenter;
@property CGFloat anchorPointZ;
@property CGFloat shadowOpacity;
@property CGSize shadowOffset;
@property CGFloat shadowRadius;
@property CGColorRef shadowColor;
@property(retain) id shadowPath;
@property float minificationFilterBias;
@property unsigned int edgeAntialiasingMask;
@property(copy) NSArray *filters;
@property(copy) NSArray *backgroundFilters;
@property(retain) id compositingFilter;
@property(copy) NSDictionary *style;
@property(copy) NSArray *actions;
@property(retain) id contents;
//@property CATransform3D transform;
@property CATransform3D sublayerTransform;

@property(copy) NSString *minificationFilter;
@property(copy) NSString *magnificationFilter;

- init;

- (void) addSublayer: (CALayer *) layer;
- (void) insertSublayer: (CALayer *) layer atIndex: (unsigned) index;
- (void) insertSublayer: (CALayer *) layer below: (CALayer *) sibling;
- (void) insertSublayer: (CALayer *) layer above: (CALayer *) sibling;
- (void) replaceSublayer: (CALayer *) layer with: (CALayer *) other;
- (void) display;
- (void) displayIfNeeded;
- (void) drawInContext: (CGContextRef) context;
- (BOOL) needsDisplay;
- (void) removeFromSuperlayer;
- (void) setNeedsDisplay;
- (void) setNeedsDisplayInRect: (CGRect) rect;

- (void) addAnimation: (CAAnimation *) animation forKey: (NSString *) key;
- (CAAnimation *) animationForKey: (NSString *) key;
- (void) removeAllAnimations;
- (void) removeAnimationForKey: (NSString *) key;
- (NSArray *) animationKeys;

- (id<CAAction>) actionForKey: (NSString *) key;

@end

@protocol CALayoutManager <NSObject>
@optional

- (CGSize) preferredSizeOfLayer: (CALayer *) layer;
- (void) invalidateLayoutOfLayer: (CALayer *) layer;
- (void) layoutSublayersOfLayer: (CALayer *) layer;

@end
