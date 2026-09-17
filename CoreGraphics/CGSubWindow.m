#import <CoreGraphics/CGSubWindow.h>
#import <Onyx2D/O2Exceptions.h>

@implementation CGSubWindow

- (void *) nativeWindow {
    O2InvalidAbstractInvocation();
    return NULL;
}

- (CGFloat) backingScaleFactor { return 1.0; }
- (CGSize) drawablePixelSize { return CGSizeZero; }
- (void) flush {}
- (BOOL) requiresMainThreadPresentation { return NO; }

- (void) show {
    O2InvalidAbstractInvocation();
}

- (void) hide {
    O2InvalidAbstractInvocation();
}

- (void) setFrame: (CGRect) frame {
    O2InvalidAbstractInvocation();
}

@end
