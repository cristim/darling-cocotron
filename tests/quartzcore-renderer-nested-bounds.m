// A parent's nonzero bounds origin must shift its descendants. CARenderer
// previously omitted this shift, placing the red child at (30, 40) instead
// of (10, 10).
#import <AppKit/AppKit.h>
#import <OpenGL/OpenGL.h>
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>

static BOOL pixelIsRed(const unsigned char *pixel) {
    return pixel[0] > 200 && pixel[1] < 20 && pixel[2] < 20 && pixel[3] > 200;
}

static BOOL pixelIsBlack(const unsigned char *pixel) {
    return pixel[0] < 20 && pixel[1] < 20 && pixel[2] < 20 && pixel[3] > 200;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];

        NSRect frame = NSMakeRect(0, 0, 64, 64);
        NSWindow *window = [[NSWindow alloc] initWithContentRect: frame
                                                      styleMask: NSBorderlessWindowMask
                                                        backing: NSBackingStoreBuffered
                                                          defer: NO];
        if (window == nil) return 1;

        NSOpenGLView *view = [[NSOpenGLView alloc] initWithFrame: frame];
        [window setContentView: view];
        [view release];

        NSOpenGLContext *context = [view openGLContext];
        if (context == nil || [context CGLContextObj] == NULL) {
            [window release];
            return 2;
        }

        [view lockFocus];
        if ([NSOpenGLContext currentContext] != context ||
            CGLGetCurrentContext() != [context CGLContextObj]) {
            [view unlockFocus];
            [window release];
            return 3;
        }

        glViewport(0, 0, 64, 64);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, 64, 0, 64, -1, 1);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        glPixelStorei(GL_PACK_ALIGNMENT, 1);
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        CALayer *root = [CALayer layer];
        root.bounds = CGRectMake(0, 0, 64, 64);
        root.anchorPoint = CGPointZero;
        root.position = CGPointZero;

        CALayer *parent = [CALayer layer];
        parent.bounds = CGRectMake(20, 30, 20, 20);
        parent.anchorPoint = CGPointZero;
        parent.position = CGPointZero;

        CALayer *child = [CALayer layer];
        child.bounds = CGRectMake(0, 0, 4, 4);
        child.anchorPoint = CGPointZero;
        child.position = CGPointMake(30, 40);
        CGColorRef red = CGColorCreateGenericRGB(1, 0, 0, 1);
        child.backgroundColor = red;
        CGColorRelease(red);
        [parent addSublayer: child];
        [root addSublayer: parent];

        CARenderer *renderer = [CARenderer rendererWithCGLContext: [context CGLContextObj]
                                                          options: nil];
        renderer.bounds = CGRectMake(0, 0, 64, 64);
        renderer.layer = root;
        [renderer render];
        glFinish();

        unsigned char shifted[4], unshifted[4];
        glReadPixels(12, 12, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, shifted);
        glReadPixels(32, 42, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, unshifted);
        GLenum error = glGetError();

        [view unlockFocus];
        [NSOpenGLContext clearCurrentContext];
        [window release];

        if (error != GL_NO_ERROR) {
            fprintf(stderr, "OpenGL error: %u\n", error);
            return 4;
        }
        if (!pixelIsRed(shifted) || !pixelIsBlack(unshifted)) {
            fprintf(stderr,
                    "shifted=(%u,%u,%u,%u) unshifted=(%u,%u,%u,%u)\n",
                    shifted[0], shifted[1], shifted[2], shifted[3],
                    unshifted[0], unshifted[1], unshifted[2], unshifted[3]);
            return 5;
        }
        return 0;
    }
}
