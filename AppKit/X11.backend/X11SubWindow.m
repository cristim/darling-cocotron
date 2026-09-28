#import "X11SubWindow.h"
#import "X11Display.h"
#import "X11Window.h"

@implementation X11SubWindow

- (CGRect) convertFrame: (CGRect) frame {
    CGFloat top, left, bottom, right;
    CGNativeBorderFrameWidthsForStyle([_parent styleMask], &top, &left, &bottom,
                                      &right);
    frame.origin.y = [_parent frame].size.height - CGRectGetMaxY(frame);
    frame.origin.y -= top;
    frame.origin.x -= left;
    return frame;
}

- (id) initWithParentWindow: (X11Window *) parent frame: (CGRect) frame {
    _parent = parent;
    // Keep the caller's logical frame before converting: -convertFrame: flips into
    // the parent's bottom-left space, and -drawablePixelSize wants points.
    _frame = frame;
    CGRect parentFrame = [self convertFrame: frame];

    _display = [(X11Display *) [NSDisplay currentDisplay] display];

    // A child window is positioned in the parent's DEVICE pixels.
    O2Rect device = [parent deviceRect: parentFrame];
    _window = XCreateSimpleWindow(_display, [parent windowHandle],
                                  device.origin.x, device.origin.y,
                                  device.size.width, device.size.height, 0, 0,
                                  0 /* border_width, border, background */
    );

    [self show];
    return self;
}

- (void) dealloc {
    XDestroyWindow(_display, _window);
    [super dealloc];
}

- (void *) nativeWindow {
    return (void *) _window;
}

- (void) show {
    XMapWindow(_display, _window);
}

- (void) hide {
    XUnmapWindow(_display, _window);
}

- (void) setFrame: (CGRect) frame {
    _frame = frame;
    O2Rect device = [_parent deviceRect: [self convertFrame: frame]];

    XMoveResizeWindow(_display, _window, device.origin.x, device.origin.y,
                      device.size.width, device.size.height);
}

- (CGFloat) backingScaleFactor {
    return [_parent backingScaleFactor];
}

- (CGSize) drawablePixelSize {
    // This window's own size, not the parent's. NSOpenGLView pairs this with
    // -[self bounds].size and expects pixels == logical * scale, so reporting the
    // parent's size gives a subwindow that does not fill its parent a viewport that
    // is too large by the ratio of the two, doubled again at 2x.
    //
    // Rounded to whole pixels: NSOpenGLView's -_drawableSize:logicalSize: rejects a
    // fractional pixel size outright, which would otherwise break every subwindow on a
    // 1.5x display.
    CGFloat scale = [self backingScaleFactor];
    return CGSizeMake(fmax(floor(_frame.size.width * scale + 0.5), 1.0),
                      fmax(floor(_frame.size.height * scale + 0.5), 1.0));
}

@end
