#import <AppKit/AppKit.h>

typedef struct {
    CGFloat firstTextBaseline;
    CGFloat lastTextBaseline;
} NSHostingBaselineOffset;

@interface _NSConstraintBasedLayoutHostingView : NSView {
    NSView *_hostedView;
}

@property (retain) NSView *hostedView;

- (instancetype)initWithHostedView:(NSView *)view;
- (NSSize)sizeThatFits:(NSSize)fits;
- (NSSize)_layoutSizeThatFits:(NSSize)fits fixedAxes:(NSUInteger)axes;
- (NSHostingBaselineOffset)_baselineOffsetsAtSize:(NSSize)size;

@end

@implementation _NSConstraintBasedLayoutHostingView

+ (BOOL)requiresConstraintBasedLayout {
    return YES;
}

- (instancetype)initWithHostedView:(NSView *)view {
    self = [super initWithFrame:NSZeroRect];
    if (self != nil)
        [self setHostedView:view];
    return self;
}

- (void)dealloc {
    [_hostedView release];
    [super dealloc];
}

- (NSView *)hostedView {
    return _hostedView;
}

- (void)setHostedView:(NSView *)view {
    if (_hostedView == view)
        return;

    NSView *oldView = _hostedView;
    _hostedView = [view retain];
    [oldView removeFromSuperview];
    [oldView release];
    if (_hostedView != nil) {
        [self addSubview:_hostedView];
        [_hostedView setFrame:[self bounds]];
    }
    self.needsLayout = YES;
    [self invalidateIntrinsicContentSize];
}

- (void)layout {
    [super layout];
    [_hostedView setFrame:[self bounds]];
}

- (NSSize)sizeThatFits:(NSSize)fits {
    if (_hostedView == nil)
        return NSZeroSize;

    NSSize size = _hostedView.intrinsicContentSize;
    NSSize frameSize = _hostedView.frame.size;
    if (size.width == NSViewNoIntrinsicMetric)
        size.width = frameSize.width > 0 ? frameSize.width : fits.width;
    if (size.height == NSViewNoIntrinsicMetric)
        size.height = frameSize.height > 0 ? frameSize.height : fits.height;
    return size;
}

- (NSSize)_layoutSizeThatFits:(NSSize)fits fixedAxes:(NSUInteger)axes {
    return [self sizeThatFits:fits];
}

- (NSHostingBaselineOffset)_baselineOffsetsAtSize:(NSSize)size {
    NSHostingBaselineOffset offsets = {0, 0};
    return offsets;
}

- (BOOL)_layoutHeightDependsOnWidth {
    return NO;
}

- (void)_informContainerThatSubviewsNeedUpdateConstraints {
    self.needsUpdateConstraints = YES;
}

- (void)_intrinsicContentSizeInvalidatedForChildView:(id)view {
    [self invalidateIntrinsicContentSize];
}

- (void)_layoutMetricsInvalidatedForHostedView {
    [self invalidateIntrinsicContentSize];
}

- (void)_setFrameWithAlignmentRect:(NSRect)rect {
    [self setFrame:rect];
}

- (NSEdgeInsets)alignmentRectInsets {
    return (NSEdgeInsets){0, 0, 0, 0};
}

- (void)constraintsDidChangeInEngine:(id)engine {
    self.needsLayout = YES;
}

- (void)sizeToFit {
    NSRect frame = [self frame];
    frame.size = [self sizeThatFits:frame.size];
    [self setFrame:frame];
}

- (void)willRemoveSubview:(NSView *)subview {
    if (subview == _hostedView) {
        [_hostedView release];
        _hostedView = nil;
    }
    [super willRemoveSubview:subview];
}

@end
