#import <Foundation/NSString.h>
#import <Foundation/NSMutableArray.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CALayerContext.h>
#import <QuartzCore/CARenderer.h>
#import "CALayerInternal.h"
#import <IOSurface/IOSurface.h>
#include <stdlib.h>
#include <stdio.h>
#import <OpenGL/CGLInternal.h>

@class CAMetalLayerInternal;

/* The X11 transport presents Chromium's flattened full-window surface.
 * Avoid uploading and compositing that same window again into a covered GL
 * child. Restrict this to the explicitly configured native presentation path. */
static BOOL hasFullWindowSurface(CALayer *layer,CGSize size) {
    id contents=layer.contents;
    static unsigned traces;
    if(getenv("DARLING_CA_LOCAL_RENDER_TRACE") && contents &&
       CFGetTypeID((CFTypeRef)contents)==IOSurfaceGetTypeID() && traces++<24)
        fprintf(stderr,"CA_LOCAL_SURFACE frame=%.0fx%.0f surface=%zux%zu\n",size.width,size.height,IOSurfaceGetWidth((IOSurfaceRef)contents),IOSurfaceGetHeight((IOSurfaceRef)contents));
    if(contents && CFGetTypeID((CFTypeRef)contents)==IOSurfaceGetTypeID() &&
       IOSurfaceGetWidth((IOSurfaceRef)contents)==(size_t)size.width &&
       IOSurfaceGetHeight((IOSurfaceRef)contents)==(size_t)size.height)return YES;
    for(CALayer *child in layer.sublayers)
        if(hasFullWindowSurface(child,size))return YES;
    return NO;
}
@implementation CALayerContext

@synthesize glContext = _glContext;
@synthesize subwindow = _subwindow;

- initWithFrame: (CGRect) rect {
    self = [super init];
    if (self == nil)
        return nil;

    _deleteTextureIds = [[NSMutableArray alloc] init];
    _frame = rect;
    /* Views can acquire a backing layer before joining a window. Defer
     * expensive native GL resources until there is a drawable. */

    return self;
}

- (void) dealloc {
    [self invalidate];
    [_deleteTextureIds release];
    [_renderer release];
    CGLReleaseContext(_glContext);
    CGLReleasePixelFormat(_pixelFormat);
    CGLDestroyWindow(_cglWindow);
    [_subwindow release];
    [super dealloc];
}

- (void) setFrame: (CGRect) rect {
    _frame = rect;
    [_subwindow setFrame: _frame];
}

- (void) setLayer: (CALayer *) layer {
    if (_layer == layer)
        return;

    layer = [layer retain];
    /* CALayer keeps a non-owning context pointer. Clear it before the old
     * context or layer can be released. */
    [_layer _setContext: nil];
    [_layer release];
    _layer = layer;

    [_layer _setContext: self];
    [_renderer setLayer: layer];

    /* darling-lol M57: the layer compositor must be driven even when no
     * CAAnimation is ever added (e.g. Chromium's compositor output). */
    [self startTimerIfNeeded];
}

- (void) setSubwindow: (CGSubWindow*) subwindow
{
    CGSubWindow* oldSubwindow = _subwindow;

    if (_cglWindow) {
        CGLDestroyWindow(_cglWindow);
    }

    _subwindow = [subwindow retain];
    _cglWindow = NULL;
    if (_subwindow != nil) {
        if (_glContext == NULL) {
            CGLPixelFormatAttribute attributes[] = { 0 };
            GLint screens;
            CGLError error = CGLChoosePixelFormat(attributes, &_pixelFormat, &screens);
            if (error == kCGLNoError)
                error = CGLCreateContext(_pixelFormat, NULL, &_glContext);
            if (error != kCGLNoError) {
                NSLog(@"CGL context creation failed with %d", error);
                CGLReleasePixelFormat(_pixelFormat);
                _pixelFormat = NULL;
            } else {
                _renderer = [[CARenderer rendererWithCGLContext: _glContext
                                                        options: nil] retain];
                [_renderer setLayer: _layer];
            }
        }
        if (_glContext != NULL)
            _cglWindow = CGLGetWindow([_subwindow nativeWindow]);
    }

    [_subwindow show];

    [oldSubwindow release];

    [_subwindow setFrame: _frame];

    // A view can attach its layer before the subwindow creates the GL context.
    // Notify the whole layer tree now that drawable resources can be created.
    [_layer _setContext: self];
    /* darling-lol M57: begin compositing once a drawable exists. */
    [self startTimerIfNeeded];
}

- (void) invalidate {
    [_timer invalidate];
    [_timer release];
    _timer = nil;

    [_layer _setContext: nil];
    [_renderer setLayer: nil];
    [_layer release];
    _layer = nil;
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

extern void darlingQCTiming(const char* what, double seconds);

- (void) renderLayer: (CALayer *) layer {
    CFTimeInterval renderLayerStart = CACurrentMediaTime();
    CGLContextMakeCurrentAndAttachToWindow(_glContext, _cglWindow);

    glEnable(GL_DEPTH_TEST);
    glShadeModel(GL_SMOOTH);

    GLint width = _frame.size.width;
    GLint height = _frame.size.height;

    glViewport(0, 0, width, height);
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

    CFTimeInterval assignStart = CACurrentMediaTime();
    darlingQCTiming("renderLayerSetup", assignStart - renderLayerStart);
    [self assignTextureIdsToLayerTree: layer];
    darlingQCTiming("assignTextureIds", CACurrentMediaTime() - assignStart);

    // this is where the Metal layer renders to an internal texture for us to use
    if ([[layer class] isSubclassOfClass: [CAMetalLayerInternal class]]) {
        CAMetalLayerInternal* mtl = (CAMetalLayerInternal*)layer;
        CFTimeInterval prepStart = CACurrentMediaTime();
        [mtl prepareRender];
        darlingQCTiming("prepareRenderTotal", CACurrentMediaTime() - prepStart);
    }

    CFTimeInterval rendererStart = CACurrentMediaTime();
    [_renderer render];
    darlingQCTiming("rendererRender", CACurrentMediaTime() - rendererStart);
}

- (void) render {
    if (_cglWindow == NULL || _layer == nil)
        return;
    if(getenv("DARLING_CA_SKIP_LOCAL_IOSURFACE_RENDER") &&
       hasFullWindowSurface(_layer,_frame.size))return;
    [self renderLayer: _layer];
}

extern void darlingQCTiming(const char* what, double seconds);

- (void) timer: (NSTimer *) timer {
    /* darling-lol M57: this is now a one-shot frame request, not an
     * unconditional 60 Hz loop. The old repeating timer ran a full software
     * GL composite of the layer tree every 16 ms even when nothing had
     * changed; under Darling that monopolised the main thread and starved
     * Chromium's task queue (JS timers, IPC), which presented as an "endless
     * synchronous IPC wait". Frames are now requested on demand (contents
     * changes / animations) and the timer stops when there is no work. */
    [_timer release];
    _timer = nil;

    if (_layer == nil || _cglWindow == NULL)
        return;

    static CFTimeInterval lastTimer = 0;
    CFTimeInterval timerStart = CACurrentMediaTime();
    if (lastTimer != 0)
        darlingQCTiming("compositorTimerInterval", timerStart - lastTimer);
    lastTimer = timerStart;

    [_renderer beginFrameAtTime: CACurrentMediaTime() timeStamp: NULL];

    [self render];
    CFTimeInterval renderDone = CACurrentMediaTime();
    darlingQCTiming("compositorRender", renderDone - timerStart);

    [_renderer endFrame];

    /* darling-lol M57: present the composited frame to the drawable. */
    [self flush];
    darlingQCTiming("compositorFlush", CACurrentMediaTime() - renderDone);

    /* Keep animating only while the layer tree actually has animations. */
    if ([_layer _treeHasAnimations])
        [self startTimerIfNeeded];
}

- (void) startTimerIfNeeded {
    if (_timer == nil)
        _timer = [[NSTimer scheduledTimerWithTimeInterval: 1.0 / 60.0
                                                   target: self
                                                 selector: @selector(timer:)
                                                 userInfo: nil
                                                  repeats: NO] retain];
}

- (void) deleteTextureId: (NSNumber *) textureId {
    [_deleteTextureIds addObject: textureId];
}

- (void) flush {
    if(getenv("DARLING_CA_SKIP_LOCAL_IOSURFACE_RENDER") && _layer &&
       hasFullWindowSurface(_layer,_frame.size))return;
    if (_glContext != NULL && _cglWindow != NULL)
        CGLFlushDrawable(_glContext);
}

@end
