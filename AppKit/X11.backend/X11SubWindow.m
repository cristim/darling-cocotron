#import "X11SubWindow.h"
#import "X11Display.h"
#import "X11Window.h"
#import <GL/glx.h>

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

    // X11 rejects zero-sized windows. Layer-backed views can initially have
    // empty frames before layout assigns their final size.
    frame.size.width = fmax(frame.size.width, 1.0);
    frame.size.height = fmax(frame.size.height, 1.0);

    _display = [(X11Display *) [NSDisplay currentDisplay] display];

    int count = 0;
    XVisualInfo match = {0};
    match.screen = DefaultScreen(_display);
    match.depth = 32;
    XVisualInfo *visuals = XGetVisualInfo(_display,
                                          VisualScreenMask | VisualDepthMask,
                                          &match, &count);
    XVisualInfo *argb = NULL;
    for (int i = 0; i < count; i++) {
        int useGL = 0, rgba = 0, doubleBuffer = 0, alpha = 0, depth = 0;
        if (glXGetConfig(_display, &visuals[i], GLX_USE_GL, &useGL) == 0 &&
            glXGetConfig(_display, &visuals[i], GLX_RGBA, &rgba) == 0 &&
            glXGetConfig(_display, &visuals[i], GLX_DOUBLEBUFFER, &doubleBuffer) == 0 &&
            glXGetConfig(_display, &visuals[i], GLX_ALPHA_SIZE, &alpha) == 0 &&
            glXGetConfig(_display, &visuals[i], GLX_DEPTH_SIZE, &depth) == 0 &&
            useGL && rgba && doubleBuffer && alpha >= 8 && depth >= 4) {
            argb = &visuals[i];
            break;
        }
    }
    if (argb) {
        _colormap = XCreateColormap(_display, RootWindow(_display, argb->screen),
                                    argb->visual, AllocNone);
        XSetWindowAttributes attributes = {0};
        attributes.colormap = _colormap;
        attributes.border_pixel = 0;
        attributes.background_pixel = 0;
        _window = XCreateWindow(_display, [parent windowHandle],
                                frame.origin.x, frame.origin.y,
                                frame.size.width, frame.size.height, 0,
                                argb->depth, InputOutput, argb->visual,
                                CWColormap | CWBorderPixel | CWBackPixel,
                                &attributes);
    } else {
        _window = XCreateSimpleWindow(_display, [parent windowHandle],
                                      frame.origin.x, frame.origin.y,
                                      frame.size.width, frame.size.height,
                                      0, 0, 0);
    }
    if (visuals)
        XFree(visuals);

    [self show];
    return self;
}

- (void) dealloc {
    XDestroyWindow(_display, _window);
    if (_colormap)
        XFreeColormap(_display, _colormap);
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
    frame = [self convertFrame: frame];
    frame.size.width = fmax(frame.size.width, 1.0);
    frame.size.height = fmax(frame.size.height, 1.0);

    XMoveResizeWindow(_display, _window, frame.origin.x, frame.origin.y,
                      frame.size.width, frame.size.height);
}

@end
