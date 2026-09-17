#import <Foundation/NSString.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CALayerContext.h>
#import <QuartzCore/CARenderer.h>
#import "CALayerInternal.h"
#import <OpenGL/CGLInternal.h>
#include <math.h>

@class CAMetalLayerInternal;

@implementation CALayerContext

@synthesize glContext = _glContext;

- initWithFrame: (CGRect) rect {
    self = [super init];
    if (self == nil)
        return nil;

    CGLError error;

    CGLPixelFormatAttribute attributes[1] = {
            0,
    };
    GLint numberOfVirtualScreens;

    error = CGLChoosePixelFormat(attributes, &_pixelFormat, &numberOfVirtualScreens);
    if (error != kCGLNoError) {
        NSLog(@"CGLChoosePixelFormat failed with %d", error);
        [self release];
        return nil;
    }

    if ((error = CGLCreateContext(_pixelFormat, NULL, &_glContext)) !=
        kCGLNoError) {
        NSLog(@"CGLCreateContext failed with %d in %s %d", error, __FILE__,
              __LINE__);
        [self release];
        return nil;
    }

    _frame = rect;

    _renderer = [[CARenderer rendererWithCGLContext: _glContext
                                            options: nil] retain];

    return self;
}

- (void) dealloc {
    [_timer invalidate];
    [_timer release];
    [_renderer release];
    CGLReleaseContext(_glContext);
    CGLReleasePixelFormat(_pixelFormat);
    if (_cglWindow != NULL)
        CGLDestroyWindow(_cglWindow);
    [_subwindow release];
    [_layer release];
    [super dealloc];
}

- (void) setFrame: (CGRect) rect {
    _frame = rect;
    [_subwindow setFrame: _frame];
}

- (void) setLayer: (CALayer *) layer {
    layer = [layer retain];
    [_layer release];
    _layer = layer;

    [_layer _setContext: self];
    [_renderer setLayer: layer];
}

- (void) setSubwindow: (CGSubWindow*) subwindow
{
    CGSubWindow* oldSubwindow = _subwindow;

    if (_cglWindow) {
        // EGL defers destruction of a current surface. Unbind before releasing
        // its native window so Mesa cannot retain a dangling wl_egl_window.
        if (CGLGetCurrentContext() == _glContext && CGLSetCurrentContext(NULL) != kCGLNoError)
            return;
        CGLDestroyWindow(_cglWindow);
    }

    _subwindow = [subwindow retain];
    _cglWindow = CGLGetWindow([_subwindow nativeWindow]);

    [_subwindow show];

    [oldSubwindow release];

    [_subwindow setFrame: _frame];
}

- (void) invalidate {
}

- (void) assignTextureIdsToLayerTree: (CALayer *) layer {

    if ([layer _textureId] == nil) {
        GLuint texture;

        glGenTextures(1, &texture);
        [layer _setTextureId: [NSNumber numberWithUnsignedInt: texture]];
    }

    for (CALayer *child in layer.sublayers)
        [self assignTextureIdsToLayerTree: child];
}

- (void) renderLayer: (CALayer *) layer {
    _rendered = NO;
    if ([_subwindow respondsToSelector: @selector(requiresMainThreadPresentation)] &&
        [_subwindow requiresMainThreadPresentation] && ![NSThread isMainThread]) {
        NSLog(@"This window backend requires OpenGL rendering on the main thread");
        return;
    }
    CGLError error = CGLContextMakeCurrentAndAttachToWindow(_glContext, _cglWindow);
    if (error != kCGLNoError) {
        NSLog(@"Layer drawable attachment failed with CGL error %d", error);
        return;
    }

    glEnable(GL_DEPTH_TEST);
    glShadeModel(GL_SMOOTH);

    CGFloat width = _frame.size.width;
    CGFloat height = _frame.size.height;
    if (!isfinite(width) || !isfinite(height) || width <= 0 || height <= 0 ||
        width > 16384 || height > 16384) return;

    // A fractional-scale backend rounds its drawable allocation once. Repeating
    // width*scale here can truncate to a different size and leave an edge stale.
    CGSize pixels = [_subwindow respondsToSelector: @selector(drawablePixelSize)]
        ? [_subwindow drawablePixelSize] : CGSizeZero;
    if (CGSizeEqualToSize(pixels, CGSizeZero)) {
        // Preserve the original API for older/native backends.
        CGFloat scale = [_subwindow respondsToSelector: @selector(backingScaleFactor)]
            ? [_subwindow backingScaleFactor] : 1.0;
        if (!isfinite(scale) || scale <= 0 ||
            ceil(width) * scale > 16384 || ceil(height) * scale > 16384) return;
        pixels = CGSizeMake(floor(ceil(width) * scale), floor(ceil(height) * scale));
    } else if (!isfinite(pixels.width) || !isfinite(pixels.height) ||
        pixels.width < 1 || pixels.height < 1 ||
        pixels.width > 16384 || pixels.height > 16384 ||
        floor(pixels.width) != pixels.width || floor(pixels.height) != pixels.height) return;
    glViewport(0, 0, (GLsizei)pixels.width, (GLsizei)pixels.height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, width, 0, height, -1, 1);

    GLsizei i = 0;
    GLuint deleteIds[[_deleteTextureIds count]];

    for (NSNumber *number in _deleteTextureIds)
        deleteIds[i++] = [number unsignedIntValue];

    if (i > 0)
        glDeleteTextures(i, deleteIds);

    [_deleteTextureIds removeAllObjects];

    [self assignTextureIdsToLayerTree: layer];

    // this is where the Metal layer renders to an internal texture for us to use
    if ([[layer class] isSubclassOfClass: [CAMetalLayerInternal class]]) {
        CAMetalLayerInternal* mtl = (CAMetalLayerInternal*)layer;
        [mtl prepareRender];
    }

    [_renderer render];
    _rendered = YES;
}

- (void) render {
    [self renderLayer: _layer];
}

static BOOL layerTreeHasAnimations(CALayer *layer) {
    if ([[layer animationKeys] count] > 0)
        return YES;
    for (CALayer *child in layer.sublayers)
        if (layerTreeHasAnimations(child))
            return YES;
    return NO;
}

- (void) timer: (NSTimer *) timer {
    [_renderer beginFrameAtTime: CACurrentMediaTime() timeStamp: NULL];

    [self render];

    [_renderer endFrame];

    // Animation frames aren't part of a view display pass, so present them here.
    [self flush];

    // beginFrameAtTime: drops finished animations. Once none are left, the frame
    // just drawn shows the final values: stop until an animation is added again.
    if (!layerTreeHasAnimations(_layer)) {
        [_timer invalidate];
        [_timer release];
        _timer = nil;
    }
}

- (void) startTimerIfNeeded {
    if (_timer == nil)
        _timer = [[NSTimer scheduledTimerWithTimeInterval: 1.0 / 60.0
                                                   target: self
                                                 selector: @selector(timer:)
                                                 userInfo: nil
                                                  repeats: YES] retain];
}

- (void) deleteTextureId: (NSNumber *) textureId {
    [_deleteTextureIds addObject: textureId];
}

- (void) flush {
    // Wayland geometry, EGL swap and parent commit must be one UI-thread
    // transaction. Do not swap first then dispatch only presentation to main.
    if ([_subwindow respondsToSelector: @selector(requiresMainThreadPresentation)] &&
        [_subwindow requiresMainThreadPresentation] && ![NSThread isMainThread]) {
        static int warned;
        if (!__sync_lock_test_and_set(&warned, 1))
            NSLog(@"This window backend requires OpenGL presentation on the main thread");
        return;
    }
    if (!_rendered) return;
    _rendered = NO;
    if (CGLFlushDrawable(_glContext) == kCGLNoError &&
        [_subwindow respondsToSelector: @selector(flush)])
        [_subwindow flush];
}

@end
