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
    frame = [self convertFrame: frame];

    _display = [(X11Display *) [NSDisplay currentDisplay] display];

    // A child window is positioned in the parent's DEVICE pixels.
    O2Rect device = [parent deviceRect: frame];
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
    O2Rect device = [_parent deviceRect: [self convertFrame: frame]];

    XMoveResizeWindow(_display, _window, device.origin.x, device.origin.y,
                      device.size.width, device.size.height);
}

- (CGFloat) backingScaleFactor {
    return [_parent backingScaleFactor];
}

- (CGSize) drawablePixelSize {
    CGRect frame = [_parent frame];
    return CGSizeMake(frame.size.width * [self backingScaleFactor],
                      frame.size.height * [self backingScaleFactor]);
}

@end
