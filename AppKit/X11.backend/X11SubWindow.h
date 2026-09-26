#import <CoreGraphics/CGSubWindow.h>
#import <X11/Xlib.h>

@class X11Window;

@interface X11SubWindow : CGSubWindow {
    X11Window *_parent;
    Display *_display;
    Window _window;
}

- initWithParentWindow: (X11Window *) parent frame: (CGRect) frame;

// CALayerContext sizes the GL viewport from -drawablePixelSize, falling back to
// -backingScaleFactor. CGSubWindow's defaults are 1.0 and CGSizeZero, which
// would give a 2x-sized subwindow a 1x viewport and show a quarter of it.
- (CGFloat) backingScaleFactor;
- (CGSize) drawablePixelSize;

@end
