#ifdef __OBJC__

#import <CoreGraphics/CGGeometry.h>
#import <Foundation/Foundation.h>

@interface CGSubWindow : NSObject

- (void *) nativeWindow;

// Physical drawable pixels per logical point (1 for unscaled backends).
- (CGFloat) backingScaleFactor;

// Exact allocated drawable size, or CGSizeZero when this backend does not
// expose it. Nonzero dimensions must be positive integral physical pixels.
- (CGSize) drawablePixelSize;

// Present after a successful drawable swap, on the window/UI thread.
- (void) flush;
- (BOOL) requiresMainThreadPresentation;

- (void) show;
- (void) hide;

- (void) setFrame: (CGRect) frame;

@end

#endif
