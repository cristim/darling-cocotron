#import <AppKit/AppKit.h>
#import <OpenGL/CGLCurrent.h>
#include <stdio.h>
#include <stdlib.h>

// Exit 77 means "no usable GL on this host"; the check below cannot run, it did not pass.
static void expect(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSOpenGLPixelFormatAttribute attributes[] = {NSOpenGLPFADoubleBuffer, 0};
        NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
        NSOpenGLContext *context = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
        if (context == nil || [context CGLContextObj] == NULL) {
            puts("SKIP: no OpenGL context can be created on this display");
            return 77;
        }

        // A view that has no window yet: nothing to attach a drawable to.
        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)];
        [context setView:view];
        expect([view window] == nil, @"fixture: the view must be detached");

        [context makeCurrentContext];
        expect([NSOpenGLContext currentContext] == context,
               @"makeCurrentContext on a detached view did not make the context current");
        expect(CGLGetCurrentContext() == [context CGLContextObj],
               @"the thread's CGL context is not the detached context");

        [NSOpenGLContext clearCurrentContext];
        expect([NSOpenGLContext currentContext] == nil, @"clearCurrentContext left a current context");
        expect(CGLGetCurrentContext() == NULL, @"clearCurrentContext left a CGL context");

        // The same, with no view at all.
        [context setView:nil];
        [context makeCurrentContext];
        expect([NSOpenGLContext currentContext] == context,
               @"makeCurrentContext with no view did not make the context current");
        [NSOpenGLContext clearCurrentContext];
        NSLog(@"PASS: appkit-detached-gl-current");
    }
    return 0;
}
