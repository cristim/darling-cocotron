/* Copyright (c) 2008 Johannes Fortmann

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE. */

#import <AppKit/NSMenuWindow.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSPopUpWindow.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSWindow.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSException.h>
#import <Foundation/NSMutableData.h>
#import <Foundation/NSProcessInfo.h>
#import <Onyx2D/O2BitmapContext.h>
#import <Onyx2D/O2Context_builtin_FT.h>
#import <Onyx2D/O2ImageSource.h>
#import <Onyx2D/O2Surface.h>
#import <QuartzCore/CAWindowOpenGLContext.h>

#import "X11Display.h"
#import "X11SubWindow.h"
#import "X11Window.h"
#import <X11/Xatom.h>
#import <X11/Xutil.h>
#import <X11/extensions/shape.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <dlfcn.h>
#include <sys/signal.h>
#include <errno.h>

#define DARLING_CA_FRAME_MAGIC 0x43414652u
#define DARLING_CA_FRAME_BUFFERED_MAGIC 0x43414632u
static size_t framePayloadOffset(uint32_t magic, uint32_t format) {
    return magic == DARLING_CA_FRAME_BUFFERED_MAGIC && (format & 0x40000000u)
        ? 32u * 1024u * 1024u : 0;
}
typedef struct {
    uint32_t magic;
    volatile uint32_t sequence;
    uint32_t width;
    uint32_t height;
    uint32_t bytesPerRow;
    uint32_t pixelFormat;
    uint64_t dataSize;
} DarlingCARemoteFrame;

@implementation X11Window

+ (Visual *) visual {
    static Visual *ret = NULL;

    if (!ret) {
        int visuals_matched, i;
        XVisualInfo match = {0};
        Display *dpy = [(X11Display *) [NSDisplay currentDisplay] display];

        XVisualInfo *info = XGetVisualInfo(dpy, 0, &match, &visuals_matched);

        for (i = 0; i < visuals_matched; i++) {
            if (info[i].depth == 32 && (info[i].red_mask == 0xff0000 &&
                                        info[i].green_mask == 0x00ff00 &&
                                        info[i].blue_mask == 0x0000ff)) {
                ret = info[i].visual;
            }
        }
        XFree(info);
        if (!ret)
            ret = DefaultVisual(dpy, DefaultScreen(dpy));
    }

    return ret;
}

static NSData *makeWindowIcon() {
    static NSMutableData *res;

    if (res != nil)
        return res;

    // Figure out the path.
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *name = [bundle objectForInfoDictionaryKey: @"CFBundleIconFile"];
    if (name == nil || [name length] == 0)
        return nil;
    NSString *path = [bundle pathForImageResource: name];
    if (path == nil) {
        NSLog(@"Cannot find an icon file named %@", name);
        return nil;
    }
    NSURL *url = [NSURL fileURLWithPath: path];

    O2ImageSource *imageSource = [O2ImageSource newImageSourceWithURL: url
                                                              options: nil];
    if (imageSource == nil) {
        NSLog(@"Cannot parse the icon");
        return nil;
    }

    res = [[NSMutableData alloc] initWithCapacity: 32 * 32 * 4 + 2];
    O2ColorSpace *colorSpace = O2ColorSpaceCreateDeviceRGB();

    // Go over the images, turning them into the required format
    // and appending them to res.
    for (NSUInteger i = 0; i < [imageSource count]; i++) {

        O2Image *image = [imageSource createImageAtIndex: i options: nil];
        NSUInteger width = O2ImageGetWidth(image);
        NSUInteger height = O2ImageGetHeight(image);

        // Render the image in ARGB.
        O2BitmapContext *context = (O2BitmapContext *) O2BitmapContextCreate(
                NULL, width, height, 8, width * 4, colorSpace,
                kO2ImageAlphaPremultipliedFirst | kO2BitmapByteOrder32Host);

        [context drawImage: image inRect: O2RectMake(0, 0, width, height)];
        int *imageData = O2BitmapContextGetData(context);

        // Convert to the format accepted by Xlib.
        NSMutableData *data =
                [NSMutableData dataWithLength: width * height * sizeof(long)];
        long *dataPtr = (long *) [data mutableBytes];
        int count = width * height;
        for (int i = 0; i < count; i++) {
            dataPtr[i] = imageData[i];
        }

        struct {
            long w, h;
        } size = {width, height};
        [res appendBytes: &size length: sizeof(size)];
        [res appendData: data];

        [context release];
        [image release];
    }

    [colorSpace release];
    [imageSource release];

    return res;
}

- (void) setWindowIcon {

    NSData *data = makeWindowIcon();

    if (data == nil)
        return;

    XChangeProperty(
            _display, _window, XInternAtom(_display, "_NET_WM_ICON", False),
            XInternAtom(_display, "CARDINAL", False), 32, PropModeReplace,
            [data bytes], [data length] / sizeof(long));
}

- (instancetype) initWithDelegate: (NSWindow *) delegate {
    _delegate = delegate;
    _level = [delegate level];
    _styleMask = [delegate styleMask];
    _backingType = (CGSBackingStoreType)[delegate backingType];
    _deviceDictionary = [NSMutableDictionary new];

    X11Display* x11disp = (X11Display *) [NSDisplay currentDisplay];
    _display = [x11disp display];

    _frame = [x11disp rootRectForFrame: [delegate frame]];
    BOOL isPanel = [delegate isKindOfClass: [NSPanel class]];
    if (isPanel && _styleMask & NSDocModalWindowMask)
        _styleMask = NSBorderlessWindowMask;
    // TODO: get rid of these glX calls
    GLint att[] = {GLX_RGBA,
                   GLX_DOUBLEBUFFER,
                   GLX_RED_SIZE,
                   4,
                   GLX_GREEN_SIZE,
                   4,
                   GLX_BLUE_SIZE,
                   4,
                   GLX_DEPTH_SIZE,
                   4,
                   None};

    int screen = DefaultScreen(_display);

    if ((_visualInfo = glXChooseVisual(_display, screen, att)) == NULL) {
        NSLog(@"glXChooseVisual failed at %s %d", __FILE__, __LINE__);
    }

    Colormap cmap =
            XCreateColormap(_display, RootWindow(_display, _visualInfo->screen),
                            _visualInfo->visual, AllocNone);

    if (cmap < 0) {
        NSLog(@"XCreateColormap failed");
        [self release];
        return nil;
    }

    XSetWindowAttributes xattr;
    unsigned long xattr_mask;
    NSString *procName = [[NSProcessInfo processInfo] processName];
    BOOL isUx = (procName && [procName rangeOfString:@"Ux" options:NSCaseInsensitiveSearch].location != NSNotFound);
    BOOL isRiot = (procName && [procName rangeOfString:@"Riot" options:NSCaseInsensitiveSearch].location != NSNotFound);
    BOOL isClient = (procName && [procName rangeOfString:@"Client" options:NSCaseInsensitiveSearch].location != NSNotFound);
    BOOL isGame = NO;
    if (!isUx && !isRiot && !isClient && procName && [procName rangeOfString:@"League" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        isGame = YES;
    }
    NSString *winTitle = [delegate respondsToSelector:@selector(title)] ? [delegate title] : nil;
    if (winTitle && [winTitle rangeOfString:@"(TM) Client" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        isGame = YES;
    }

    BOOL isMenuOrPopup = NO;
    if (delegate) {
        if ([delegate isKindOfClass:NSClassFromString(@"NSMenuWindow")] ||
            [delegate isKindOfClass:NSClassFromString(@"NSPopUpWindow")] ||
            [delegate isKindOfClass:NSClassFromString(@"NSToolTipPanel")]) {
            isMenuOrPopup = YES;
        }
    }

    // A borderless game is still a focusable application window. Leaving it
    // override-redirect makes XWayland bypass compositor keyboard activation.
    // Menus and nonactivating popups keep their unmanaged behavior.
    xattr.override_redirect = (!isGame && _styleMask == NSBorderlessWindowMask && isMenuOrPopup) ? True : False;
    xattr_mask = CWOverrideRedirect | CWColormap;
    xattr.colormap = cmap;

    _window = XCreateWindow(
            _display, DefaultRootWindow(_display), _frame.origin.x,
            _frame.origin.y, _frame.size.width, _frame.size.height, 0,
            (_visualInfo == NULL) ? CopyFromParent : _visualInfo->depth,
            InputOutput,
            (_visualInfo == NULL) ? CopyFromParent : _visualInfo->visual,
            xattr_mask, &xattr);

    /* Keep Cocoa's process identifier available to cross-process activation. */
    unsigned long windowPID = (unsigned long)getpid();
    XChangeProperty(_display, _window, XInternAtom(_display, "_NET_WM_PID", False),
                    XA_CARDINAL, 32, PropModeReplace,
                    (unsigned char *)&windowPID, 1);

    [self syncDelegateProperties];

    Atom atm = XInternAtom(_display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(_display, _window, &atm, 1);

    const char *name = [[[NSProcessInfo processInfo] processName] UTF8String];

    XClassHint classHint = {.res_name = (char *) name,
                            .res_class = (char *) name};
    XSetClassHint(_display, _window, &classHint);

    if (isGame && (_styleMask == NSBorderlessWindowMask || !(_styleMask & NSTitledWindowMask))) {
        Atom state = XInternAtom(_display, "_NET_WM_STATE", False);
        Atom fs = XInternAtom(_display, "_NET_WM_STATE_FULLSCREEN", False);
        XChangeProperty(_display, _window, state, XA_ATOM, 32, PropModeReplace,
                        (const unsigned char *)&fs, 1);
        /* darling-lol: Tell compositor NEVER to bypass composition (bypass=2).
         * Direct scanout of this parent window produces a black screen because
         * OpenGL/Metal renders into the child X11SubWindow. */
        unsigned long bypass = 2;
        XChangeProperty(_display, _window, XInternAtom(_display, "_NET_WM_BYPASS_COMPOSITOR", False),
                        XA_CARDINAL, 32, PropModeReplace, (unsigned char *)&bypass, 1);
    }

    XSetWindowBackgroundPixmap(_display, _window, None);

    _isModal = [delegate isSheet] || [NSApp modalWindow] == delegate;
    // FIXME: There should be no need for this.
    _isModal |= [delegate isKindOfClass: NSClassFromString(@"NSSavePanel")];

    const char *windowType;
    BOOL isTransient = YES;
    if (_isModal) {
        windowType = "_NET_WM_WINDOW_TYPE_DIALOG";
    } else if ([delegate isKindOfClass: [NSMenuWindow class]] ||
               [delegate isKindOfClass: [NSPopUpWindow class]]) {
        windowType = "_NET_WM_WINDOW_TYPE_MENU";
    } else if (isPanel) {
        windowType = "_NET_WM_WINDOW_TYPE_UTILITY";
    } else {
        windowType = "_NET_WM_WINDOW_TYPE_NORMAL";
        isTransient = NO;
    }
    long windowTypeAtom = (long) XInternAtom(_display, windowType, False);
    XChangeProperty(_display, _window,
                    XInternAtom(_display, "_NET_WM_WINDOW_TYPE", False),
                    XA_ATOM, 32, PropModeReplace,
                    (const unsigned char *) &windowTypeAtom, 1);

    if (isTransient && [NSApp mainWindow]) {
        X11Window *mainWindow =
                (X11Window *) [[NSApp mainWindow] platformWindow];
        XSetTransientForHint(_display, _window, [mainWindow windowHandle]);
    }

    _xic = XCreateIC(x11disp->_xim,
        XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
        XNClientWindow, _window,
        XNFocusWindow, _window,
        NULL);

    _cglWindow = CGLGetWindow((void *) _window);

    [(X11Display *) [NSDisplay currentDisplay] setWindow: self forID: _window];

    // FIXME: Move this call into setStyleMaskInternal below!
    if (_styleMask == NSBorderlessWindowMask) {
        [[self class] removeDecorationForWindow: _window onDisplay: _display];
    }
    [self setStyleMaskInternal: _styleMask force: YES];

    [self setWindowIcon];

    /* Poll the host-visible remote CA frame on the AppKit/main runloop. */
    _remoteFrameTimer = [[NSTimer scheduledTimerWithTimeInterval: 1.0 / 60.0
        target: self selector: @selector(presentRemoteCAFrame:)
        userInfo: nil repeats: YES] retain];

    return self;
}

- (void) dealloc {
    [self invalidate];
    [_deviceDictionary release];
    [super dealloc];
}

- (NSUInteger) styleMask {
    return _styleMask;
}

- (void) setStyleMaskInternal: (NSUInteger) mask force: (BOOL) force {
    if (force || (mask & NSWindowStyleMaskResizable) !=
                         (_styleMask & NSWindowStyleMaskResizable)) {
        XSizeHints *sh = XAllocSizeHints();
        if (mask & NSWindowStyleMaskResizable) {
            // Make resizable
            sh->flags = 0;
        } else {
            NSString *procName = [[NSProcessInfo processInfo] processName];
            BOOL isGame = (procName && [procName rangeOfString:@"League" options:NSCaseInsensitiveSearch].location != NSNotFound &&
                           [procName rangeOfString:@"Ux" options:NSCaseInsensitiveSearch].location == NSNotFound);
            if (isGame || mask == NSBorderlessWindowMask) {
                sh->flags = PMinSize;
                sh->min_width = _frame.size.width;
                sh->min_height = _frame.size.height;
            } else {
                // Make non-resizable
                sh->flags = PMinSize | PMaxSize;
                sh->min_width = sh->max_width = _frame.size.width;
                sh->min_height = sh->max_height = _frame.size.height;
            }
        }

        XSetWMSizeHints(_display, _window, sh, XA_WM_NORMAL_HINTS);
        XFree(sh);
    }

    if (!_mapped) {
        long states[2];
        int states_cnt = 0;
        if (_isModal) {
            states[states_cnt++] =
                    (long) XInternAtom(_display, "_NET_WM_STATE_MODAL", False);
        }
        if (mask & NSWindowStyleMaskFullScreen) {
            states[states_cnt++] = (long) XInternAtom(
                    _display, "_NET_WM_STATE_FULLSCREEN", False);
        }
        XChangeProperty(_display, _window,
                        XInternAtom(_display, "_NET_WM_STATE", False), XA_ATOM,
                        32, PropModeReplace, (const unsigned char *) states,
                        states_cnt);
    } else if (force || ((mask & NSWindowStyleMaskFullScreen) !=
                         (_styleMask & NSWindowStyleMaskFullScreen))) {
        XClientMessageEvent event = {0};
        event.type = ClientMessage;
        event.window = _window;
        event.message_type = XInternAtom(_display, "_NET_WM_STATE", False);
        event.format = 32;
        event.data.l[0] = (mask & NSWindowStyleMaskFullScreen) ? 1 : 2;
        event.data.l[1] =
                (long) XInternAtom(_display, "_NET_WM_STATE_FULLSCREEN", False);
        event.data.l[3] = 1;
        XSendEvent(_display, DefaultRootWindow(_display), False,
                   SubstructureNotifyMask | SubstructureRedirectMask,
                   (XEvent *) &event);
    }
}

- (void) setStyleMask: (NSUInteger) mask {
    NSLog(@"X11Window setStyleMask: 0x%lx\n", (unsigned long) mask);

    [self setStyleMaskInternal: mask force: NO];

    _styleMask = mask;
}

+ (void) removeDecorationForWindow: (Window) w onDisplay: (Display *) dpy {
    struct {
        unsigned long flags;
        unsigned long functions;
        unsigned long decorations;
        long input_mode;
        unsigned long status;
    } hints = {
            2, 0, 0, 0, 0,
    };
    XChangeProperty(dpy, w, XInternAtom(dpy, "_MOTIF_WM_HINTS", False),
                    XInternAtom(dpy, "_MOTIF_WM_HINTS", False), 32,
                    PropModeReplace, (const unsigned char *) &hints,
                    sizeof(hints) / sizeof(long));
}

- (void) ensureMapped {
    if (!_mapped) {
        XMapWindow(_display, _window);
        _mapped = YES;
        _remoteFrameTargetRefresh = 0;
    }
}

- (void) showWindowWithoutActivation {
    [self ensureMapped];
}

- (void) setDelegate: delegate {
    _delegate = delegate;
    [self syncDelegateProperties];
}

- delegate {
    return _delegate;
}

- (void) syncDelegateProperties {
    long mask = KeyPressMask | KeyReleaseMask | ExposureMask |
                StructureNotifyMask | EnterWindowMask | LeaveWindowMask |
                ButtonPressMask | ButtonReleaseMask | ButtonMotionMask | PointerMotionMask |
                VisibilityChangeMask | FocusChangeMask | PropertyChangeMask |
                SubstructureRedirectMask;

    /* Motion also restores a cursor hidden while typing. App-level motion
     * delivery is still filtered by acceptsMouseMovedEvents in X11Display. */
    XSelectInput(_display, _window, mask);

    /* Mouse-transparent windows must not steal crossing events from the
     * view below them. Filtering dispatched events leaves X11 hit testing
     * unchanged and can repeatedly hide/recreate tooltip windows. */
    if ([_delegate respondsToSelector: @selector(ignoresMouseEvents)]) {
        if ([_delegate ignoresMouseEvents])
            XShapeCombineRectangles(_display, _window, ShapeInput,
                                    0, 0, NULL, 0, ShapeSet, Unsorted);
        else
            XShapeCombineMask(_display, _window, ShapeInput,
                              0, 0, None, ShapeSet);
        XFlush(_display);
    }

    // TODO: background color
}

- (void) invalidate {
    // This is essentially dealloc; we release our contexts
    // and windows, but unlike dealloc, this method can be called
    // several times, so set everything to nil/NULL/0.
    [_remoteFrameTimer invalidate];
    [_remoteFrameTimer release];
    _remoteFrameTimer = nil;
    if (_remoteFrameShm) {
        _remoteFrameShmDestroy(_remoteFrameShm);
        _remoteFrameShm = NULL;
        _remoteFrameShmPumping = NO;
    }
    if (_remoteFrameMapping) {
        munmap(_remoteFrameMapping, _remoteFrameMappingSize);
        _remoteFrameMapping = NULL;
        _remoteFrameMappingSize = 0;
    }

    if (_remoteFrameWindow) {
        [(X11Display *) [NSDisplay currentDisplay] setWindow: nil forID: _remoteFrameWindow];
        if (_remoteFrameGC) XFreeGC(_display, _remoteFrameGC);
        XDestroyWindow(_display, _remoteFrameWindow);
        _remoteFrameWindow = 0;
        _remoteFrameGC = NULL;
        _remoteFrameValid = NO;
    }
    [_context release];
    _context = nil;

    [_delegate platformWindowDidInvalidateCGContext: self];
    _delegate = nil;

    [_caContext release];
    _caContext = nil;

    if (_cglContext != NULL) {
        CGLReleaseContext(_cglContext);
        _cglContext = NULL;
    }
    if (_cglWindow != NULL) {
        CGLDestroyWindow(_cglWindow);
        _cglWindow = NULL;
    }

    if (_window) {
        XDestroyIC(_xic);

        [(X11Display *) [NSDisplay currentDisplay] setWindow: nil
                                                       forID: _window];
        XDestroyWindow(_display, _window);
        _window = 0;
    }
}

- (void) setRemoteFrameTimerSlow: (BOOL) slow {
    if (_remoteFrameTimerSlow == slow) return;
    _remoteFrameTimerSlow = slow;
    [_remoteFrameTimer invalidate];
    [_remoteFrameTimer release];
    _remoteFrameTimer = [[NSTimer scheduledTimerWithTimeInterval: slow ? 0.25 : 1.0 / 60.0
        target: self selector: @selector(presentRemoteCAFrame:)
        userInfo: nil repeats: YES] retain];
}

- (BOOL) presentRemoteCAFrame: (NSTimer *) timer {
    static unsigned char *pixels;
    static size_t pixelCapacity;
    if (!_mapped) return NO;
    double now = CFAbsoluteTimeGetCurrent();
    /* X geometry queries are synchronous round trips. Cache stable targets
     * across animation ticks, invalidating on native resize/mapping changes. */
    if (!_remoteFrameTargetCount || now >= _remoteFrameTargetRefresh) {
        XWindowAttributes attributes;
        if (!XGetWindowAttributes(_display, _window, &attributes) ||
            attributes.map_state != IsViewable)
            return NO;
        _remoteFrameTargetCount = 1;
        _remoteFrameTargets[0] = attributes;
        Window root, parent, *children = NULL;
        unsigned childCount = 0;
        if (XQueryTree(_display, _window, &root, &parent, &children, &childCount)) {
            for (unsigned i = 0; i < childCount && _remoteFrameTargetCount < 17; ++i)
                if (children[i] != _remoteFrameWindow &&
                    XGetWindowAttributes(_display, children[i],
                        &_remoteFrameTargets[_remoteFrameTargetCount]))
                    ++_remoteFrameTargetCount;
        }
        if (children) XFree(children);
        _remoteFrameTargetRefresh = now + 1.0;
    }
    XWindowAttributes *frameTargets = _remoteFrameTargets;
    unsigned frameTargetCount = _remoteFrameTargetCount;
    DarlingCARemoteFrame before, after;
    if (_remoteFrameValid && _remoteFrameMapping &&
        (((DarlingCARemoteFrame *)_remoteFrameMapping)->sequence & 1)) {
        XRaiseWindow(_display, _remoteFrameWindow);
        XFlush(_display);
        return YES;
    }
    /* darling-lol M58c diagnostic (opt-in via M58_PRES_TRACE): one character
     * per event appended to /dev/shm/m58c-present-<pid> so the consumer's
     * behavior can be observed from the host without guest logging noise.
     * t=timer fired, s=no candidate slot, S=slot chosen, s=same sequence,
     * b=blit performed, v=header validation failed. */
    int (*_tputc)(int) = NULL;
    (void) _tputc;
    static FILE *tlog;
    if (getenv("M58_PRES_TRACE")) {
        if (!tlog) {
            char tpath[128];
            snprintf(tpath, sizeof(tpath),
                "/dev/shm/m58c-present-%d", (int) getpid());
            tlog = fopen(tpath, "a");
        }
        if (tlog) {
            fputc('t', tlog);
            fflush(tlog);
        }
    }
    /* darling-lol M58c: the publisher side now writes one slot file per
     * process (/dev/shm/darling-ca-frame-<uid>-<pid>) because concurrent
     * publishers corrupt a shared slot's seqlock. Several processes publish
     * same-size surfaces (measured: the browser's own surface is all black
     * while the GPU's compositor output carries the real frame), so scan
     * every publisher's slot and display the most recently updated one that
     * actually contains pixels; an all-black frame is only used when nothing
     * else is available. */
    char path[128], bestPath[128], bestBlackPath[128];
    /* A window no publisher has a slot for (a Metal game window never gets one) used to rescan /dev/shm on every
     * 60 Hz tick: opendir, readdir and stat/open/pread/close per slot file on the main thread. */
    if (!_remoteFrameMapping && now < _remoteFrameSelectionRefresh)
        return _remoteFrameValid;
    if (_remoteFrameMapping && now < _remoteFrameSelectionRefresh) {
        snprintf(path, sizeof(path), "%s", _remoteFrameMappingPath);
        goto selectedFrame;
    }
    _remoteFrameSelectionRefresh = now + 0.25;
    bestPath[0] = bestBlackPath[0] = '\0';
    uint64_t bestMtime = 0, bestBlackMtime = 0;
    BOOL bestSoftware = NO;

    char prefix[32];
    snprintf(prefix, sizeof(prefix), "darling-ca-frame-%u-", getuid());
    size_t prefixLen = strlen(prefix);
    DIR *dir = opendir("/dev/shm");
    if (dir) {
        struct dirent *ent;
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, prefix, prefixLen) != 0)
                continue;
            char candidate[128];
            snprintf(candidate, sizeof(candidate), "/dev/shm/%s",
                ent->d_name);
            struct stat st;
            if (stat(candidate, &st) != 0)
                continue;
            uint64_t updateTime = (uint64_t)st.st_mtimespec.tv_sec * 1000000000u +
                                  st.st_mtimespec.tv_nsec;
            DarlingCARemoteFrame head = {0};
            int cfd = open(candidate, O_RDONLY);
            if (cfd < 0)
                continue;
            BOOL ok = (pread(cfd, &head, sizeof(head), 0) == sizeof(head) &&
                (head.magic == DARLING_CA_FRAME_MAGIC || head.magic == DARLING_CA_FRAME_BUFFERED_MAGIC) &&
                !(head.sequence & 1) &&
                head.width && head.height &&
                head.bytesPerRow >= head.width * 4 &&
                head.dataSize == (uint64_t)head.bytesPerRow * head.height &&
                head.dataSize <= 64u * 1024u * 1024u);
            close(cfd);
            BOOL matchesWindow = NO;
            for (unsigned i = 0; i < frameTargetCount; ++i)
                if (head.width == (unsigned)frameTargets[i].width &&
                    head.height == (unsigned)frameTargets[i].height)
                    matchesWindow = YES;
            if (!ok || !matchesWindow)
                continue;

            /* Peek the top rows to distinguish a rendered frame from an
             * empty (all-zero) surface of the same size. */
            BOOL hasPixels = NO;
            size_t peekRows = head.height < 40 ? (size_t) head.height : 40;
            size_t peekLen = peekRows * head.bytesPerRow;
            unsigned char peek[40 * 4096];
            if (peekLen > sizeof(peek))
                peekLen = sizeof(peek);
            int pfd = open(candidate, O_RDONLY);
            if (pfd >= 0) {
                if (pread(pfd, peek, peekLen, sizeof(head) + framePayloadOffset(head.magic, head.pixelFormat)) ==
                    (ssize_t) peekLen) {
                    for (size_t i = 0; i + 3 < peekLen; i += 4) {
                        if (peek[i] | peek[i + 1] | peek[i + 2]) {
                            hasPixels = YES;
                            break;
                        }
                    }
                }
                close(pfd);
            }

            if (hasPixels) {
                BOOL software = (head.pixelFormat & 0x80000000u) != 0;
                if ((software && !bestSoftware) ||
                    (software == bestSoftware && updateTime > bestMtime)) {
                    bestSoftware = software;
                    bestMtime = updateTime;
                    snprintf(bestPath, sizeof(bestPath), "%s", candidate);
                }
            } else if (updateTime > bestBlackMtime) {
                bestBlackMtime = updateTime;
                snprintf(bestBlackPath, sizeof(bestBlackPath), "%s", candidate);
            }
        }
        closedir(dir);
    }

    /* Keep a software owner across popup updates while the presented size
     * still belongs to this window. After a real resize, retaining that owner
     * can strand us on its popup slot even though a matching readback frame
     * is ready from another publisher. Let normal candidate selection make
     * that handoff when the old presentation no longer matches a target. */
    BOOL presentationMatchesTarget = NO;
    for (unsigned i = 0; i < frameTargetCount; ++i)
        if (_remoteFrameWidth == (unsigned)frameTargets[i].width &&
            _remoteFrameHeight == (unsigned)frameTargets[i].height)
            presentationMatchesTarget = YES;
    if (_remoteFrameSoftwarePublisher && _remoteFrameMapping && !bestSoftware &&
        presentationMatchesTarget) {
        const char *pidText = strrchr(_remoteFrameMappingPath, '-');
        int publisher = pidText ? atoi(pidText + 1) : 0;
        if (publisher > 0 && (kill(publisher, 0) == 0 || errno != ESRCH)) {
            snprintf(path, sizeof(path), "%s", _remoteFrameMappingPath);
            goto selectedFrame;
        }
    }
    if (bestPath[0] != '\0')
        snprintf(path, sizeof(path), "%s", bestPath);
    else if (bestBlackPath[0] != '\0')
        snprintf(path, sizeof(path), "%s", bestBlackPath);
    else {
        /* A writer's odd sequence is a temporary gap, not a hidden window.
         * Keep the last complete frame instead of exposing local GL pixels. */
        if (tlog) { fputc('S', tlog); }
        if (!_remoteFrameMapping) _remoteFrameSelectionRefresh = now + 0.5;
        return _remoteFrameValid;
    }

    if (tlog) { fputc('S', tlog); }

    /* Only the presentation child owns remote pixels. GL swaps in sibling
     * views cannot clear it, so unchanged frames need no repeated pixel copy. */
selectedFrame:
    if (!_remoteFrameMapping || strcmp(_remoteFrameMappingPath, path)) {
        int fd = open(path, O_RDONLY);
        if (fd < 0) return _remoteFrameValid;
        struct stat st;
        if (fstat(fd, &st) || st.st_size < sizeof(before) ||
            st.st_size > sizeof(before) + 64u * 1024u * 1024u) {
            close(fd); return _remoteFrameValid;
        }
        void *mapping = mmap(NULL, st.st_size, PROT_READ, MAP_SHARED, fd, 0);
        close(fd);
        if (mapping == MAP_FAILED) return _remoteFrameValid;
        if (_remoteFrameMapping) munmap(_remoteFrameMapping, _remoteFrameMappingSize);
        _remoteFrameMapping = mapping;
        _remoteFrameSoftwarePublisher = NO;
        _remoteFrameMappingSize = st.st_size;
        snprintf(_remoteFrameMappingPath, sizeof(_remoteFrameMappingPath), "%s", path);
    }
    memcpy(&before, _remoteFrameMapping, sizeof(before));
    __sync_synchronize();
    if ((before.magic != DARLING_CA_FRAME_MAGIC && before.magic != DARLING_CA_FRAME_BUFFERED_MAGIC) || (before.sequence & 1) ||
        !before.width || !before.height || before.bytesPerRow < before.width * 4 ||
        before.dataSize != (uint64_t)before.bytesPerRow * before.height ||
        framePayloadOffset(before.magic, before.pixelFormat) > _remoteFrameMappingSize - sizeof(before) ||
        before.dataSize > _remoteFrameMappingSize - sizeof(before) - framePayloadOffset(before.magic, before.pixelFormat))
        return _remoteFrameValid;
    if (before.pixelFormat & 0x80000000u) _remoteFrameSoftwarePublisher = YES;
    BOOL matchesTarget = NO;
    for (unsigned i = 0; i < frameTargetCount; ++i)
        if (before.width == (unsigned)frameTargets[i].width &&
            before.height == (unsigned)frameTargets[i].height) matchesTarget = YES;
    /* A GPU process may publish several windows into its slot. Never resize
     * our presentation child to another window's intervening surface. */
    if (!matchesTarget) return _remoteFrameValid;
    int frameX = 0, frameY = 0;
    for (unsigned i = 0; i < frameTargetCount; ++i) {
        if (before.width == (unsigned)frameTargets[i].width &&
            before.height == (unsigned)frameTargets[i].height) {
            if (i) { frameX = frameTargets[i].x; frameY = frameTargets[i].y; }
            break;
        }
    }
    if (_remoteFrameWindow)
        XMoveWindow(_display, _remoteFrameWindow, frameX, frameY);
    if (_remoteFrameShmPumping && _remoteFrameWidth == before.width &&
        _remoteFrameHeight == before.height) {
        _remoteFrameShmStart(_remoteFrameShm, _remoteFrameWindow, _remoteFrameGC, path);
        if (!_remoteFrameValid)
            _remoteFrameShmPut(_remoteFrameShm, _remoteFrameWindow, _remoteFrameGC, NULL, 0);
        XRaiseWindow(_display, _remoteFrameWindow);
        XFlush(_display);
        _remoteFrameSequence = before.sequence;
        snprintf(_remoteFramePath, sizeof(_remoteFramePath), "%s", path);
        _remoteFrameValid = YES;
        return YES;
    }
    if (_remoteFrameValid && _remoteFrameWindow &&
        _remoteFrameSequence == before.sequence &&
        _remoteFrameWidth == before.width && _remoteFrameHeight == before.height &&
        strcmp(_remoteFramePath, path) == 0) {
        XRaiseWindow(_display, _remoteFrameWindow);
        XFlush(_display);
        return YES;
    }
    if (pixelCapacity < before.dataSize) {
        unsigned char *newPixels = realloc(pixels, before.dataSize);
        if (!newPixels) {
            return _remoteFrameValid;
        }
        pixels = newPixels;
        pixelCapacity = before.dataSize;
    }
    memcpy(pixels, (char *)_remoteFrameMapping + sizeof(before) + framePayloadOffset(before.magic, before.pixelFormat), before.dataSize);
    __sync_synchronize();
    memcpy(&after, _remoteFrameMapping, sizeof(after));
    if (after.sequence != before.sequence || (after.sequence & 1)) {
        if (tlog) { fputc('T', tlog); }
        return _remoteFrameValid;
    }

    XImage *image = XCreateImage(_display, _visualInfo->visual,
        _visualInfo->depth, ZPixmap, 0, (char *)pixels, before.width,
        before.height, 32, before.bytesPerRow);
    if (!image)
        return _remoteFrameValid;

    if (!_remoteFrameWindow) {
        int shapeMajor, shapeMinor;
        if (!XShapeQueryVersion(_display, &shapeMajor, &shapeMinor) ||
            shapeMajor < 1 || (shapeMajor == 1 && shapeMinor < 1)) {
            image->data = NULL;
            XDestroyImage(image);
            return _remoteFrameValid;
        }
        XSetWindowAttributes attrs = {0};
        attrs.background_pixmap = None;
        attrs.event_mask = ExposureMask;
        _remoteFrameWindow = XCreateWindow(_display, _window, frameX, frameY,
            before.width, before.height, 0, CopyFromParent, InputOutput,
            CopyFromParent, CWBackPixmap | CWEventMask, &attrs);
        /* An empty input shape lets clicks and motion reach native views. */
        XShapeCombineRectangles(_display, _remoteFrameWindow, ShapeInput,
            0, 0, NULL, 0, ShapeSet, Unsorted);
        [(X11Display *) [NSDisplay currentDisplay] setWindow: self forID: _remoteFrameWindow];
        _remoteFrameGC = XCreateGC(_display, _remoteFrameWindow, 0, NULL);
    }
    if (_remoteFrameWidth != before.width || _remoteFrameHeight != before.height) {
        if (_remoteFrameShm) {
            _remoteFrameShmDestroy(_remoteFrameShm);
            _remoteFrameShm = NULL;
            _remoteFrameShmPumping = NO;
            [self setRemoteFrameTimerSlow: NO];
        }
        XResizeWindow(_display, _remoteFrameWindow, before.width, before.height);
        _remoteFrameWidth = before.width;
        _remoteFrameHeight = before.height;
    }
    XMapRaised(_display, _remoteFrameWindow);
    typedef void *(*CreateShm)(Display *, Visual *, unsigned, unsigned, unsigned);
    typedef int (*PutShm)(void *, Drawable, GC, const void *, size_t);
    static CreateShm createShm;
    static PutShm putShm;
    static void (*destroyShm)(void *);
    static int (*startShm)(void *, Drawable, GC, const char *);
    static BOOL checkedShm;
    if (!checkedShm) {
        checkedShm = YES;
        const char *transportPath = getenv("DARLING_XSHM_LIBRARY");
        const char *shmOption = getenv("RCLOL_XSHM");
        void *transport = (shmOption && shmOption[0] == '0') ? NULL :
            dlopen(transportPath ? transportPath : "/usr/lib/native/libDarlingXShm.dylib",
                RTLD_NOW | RTLD_LOCAL);
        void *(*getCreate)(void) = transport ? dlsym(transport, "DarlingXShmGetCreate") : NULL;
        void *(*getPut)(void) = transport ? dlsym(transport, "DarlingXShmGetPut") : NULL;
        void *(*getDestroy)(void) = transport ? dlsym(transport, "DarlingXShmGetDestroy") : NULL;
        void *(*getStart)(void) = transport ? dlsym(transport, "DarlingXShmGetStart") : NULL;
        if (getCreate && getPut && getDestroy) {
            createShm = (CreateShm)getCreate();
            putShm = (PutShm)getPut();
            destroyShm = (void (*)(void *))getDestroy();
            if (getStart) startShm = (int (*)(void *, Drawable, GC, const char *))getStart();
        }
    }
    if (!_remoteFrameShm && createShm && putShm && destroyShm) {
        /* The independent connection must see this client's child creation
         * before issuing its first upload or creating its private GC. */
        XSync(_display, False);
        _remoteFrameShm = createShm(_display, _visualInfo->visual,
            _visualInfo->depth, before.width, before.height);
        _remoteFrameShmDestroy = destroyShm;
        _remoteFrameShmPut = putShm;
        _remoteFrameShmStart = startShm;
        if (getenv("RCLOL_XSHM_TRACE")) {
            extern int __simple_printf(const char *, ...);
            __simple_printf("REMOTE_XSHM width=%u height=%u active=%d\n",
                before.width, before.height, _remoteFrameShm != NULL);
        }
    }
    if (!_remoteFrameShm || !putShm(_remoteFrameShm, _remoteFrameWindow,
            _remoteFrameGC, pixels, before.bytesPerRow)) {
        XPutImage(_display, _remoteFrameWindow, _remoteFrameGC, image, 0, 0, 0, 0,
            before.width, before.height);
        XFlush(_display);
    }
    if (_remoteFrameShm && startShm && !_remoteFrameShmPumping) {
        _remoteFrameShmPumping = startShm(_remoteFrameShm, _remoteFrameWindow, _remoteFrameGC, path);
        if (_remoteFrameShmPumping) [self setRemoteFrameTimerSlow: YES];
    }
    _remoteFrameSequence = before.sequence;
    snprintf(_remoteFramePath, sizeof(_remoteFramePath), "%s", path);
    _remoteFrameValid = YES;
    image->data = NULL; /* pixels is reused by the next frame */
    XDestroyImage(image);
    if (tlog) { fputc('b', tlog); fflush(tlog); }
    return YES;
}

- (BOOL) handleRemoteFrameExpose: (Window) window {
    if (!window || window != _remoteFrameWindow)
        return NO;
    _remoteFrameValid = NO;
    [self presentRemoteCAFrame: nil];
    return YES;
}

- (Window) windowHandle {
    return _window;
}

- (O2Context *) createCGContextIfNeeded {
    if (_context == nil) {
        O2ColorSpaceRef colorSpace = O2ColorSpaceCreateDeviceRGB();
        O2Surface *surface = [[O2Surface alloc]
                   initWithBytes: NULL
                           width: _frame.size.width
                          height: _frame.size.height
                bitsPerComponent: 8
                     bytesPerRow: 0
                      colorSpace: colorSpace
                      bitmapInfo: kO2ImageAlphaPremultipliedFirst |
                                  kO2BitmapByteOrder32Little];
        O2ColorSpaceRelease(colorSpace);
        _context = [[O2Context_builtin_FT alloc] initWithSurface: surface
                                                         flipped: NO];
    }
    return _context;
}

- (O2Context *) cgContext {
    return [self createCGContextIfNeeded];
}

- (void) invalidateContextWithNewSize: (NSSize) size
                         forceRebuild: (BOOL) forceRebuild
{
    if (!NSEqualSizes(_frame.size, size) || forceRebuild) {
        _frame.size = size;
        if (![_context resizeWithNewSize: size]) {
            [_context release];
            _context = nil;
            [_delegate platformWindowDidInvalidateCGContext: self];
        }
    }
}

- (void) invalidateContextWithNewSize: (NSSize) size {
    [self invalidateContextWithNewSize: size forceRebuild: NO];
}

- (void) setTitle: (NSString *) title {
    XTextProperty prop;
    const char *text = [title cString];
    XStringListToTextProperty((char **) &text, 1, &prop);
    XSetWMName(_display, _window, &prop);
    if (title && [title rangeOfString:@"(TM) Client" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        [(X11Display *)[NSDisplay currentDisplay] updateMouseConfinementForWindow:self];
    }
}

- (void) setFrame: (O2Rect) frame {
    frame = [(X11Display *) [NSDisplay currentDisplay] rootRectForFrame: frame];
    XMoveResizeWindow(_display, _window, frame.origin.x, frame.origin.y,
                      frame.size.width, frame.size.height);
    [self invalidateContextWithNewSize: frame.size];
    _frame = frame;
    // Nonresizable windows can be created at 1x1 and enlarged before display.
    // Refresh the constraints so a managing compositor sees the current size.
    if (!(_styleMask & NSWindowStyleMaskResizable)) {
        NSString *procName = [[NSProcessInfo processInfo] processName];
        BOOL isGame = (procName && [procName rangeOfString:@"League" options:NSCaseInsensitiveSearch].location != NSNotFound &&
                       [procName rangeOfString:@"Ux" options:NSCaseInsensitiveSearch].location == NSNotFound);
        if (!isGame && _styleMask != NSBorderlessWindowMask) {
            XSizeHints hints = {0};
            hints.flags = PMinSize | PMaxSize;
            hints.min_width = hints.max_width = frame.size.width;
            hints.min_height = hints.max_height = frame.size.height;
            XSetWMSizeHints(_display, _window, &hints, XA_WM_NORMAL_HINTS);
        }
    }
}

- (void) setHasShadow: (BOOL) value {
    _hasShadow = value;
}

- (void) setLevel: (int) value {
    _level = value;
}

/* NSApplication's attention timer calls this for requestUserAttention:. The
 * CGWindow base class raises an abstract-invocation exception, which aborted
 * the whole LeagueClientUx process. Ask the window manager to mark the window
 * as demanding attention instead. */
- (void) flashWindow {
    XClientMessageEvent event = {0};
    event.type = ClientMessage;
    event.window = _window;
    event.message_type = XInternAtom(_display, "_NET_WM_STATE", False);
    event.format = 32;
    event.data.l[0] = 1; /* _NET_WM_STATE_ADD */
    event.data.l[1] = (long) XInternAtom(_display, "_NET_WM_STATE_DEMANDS_ATTENTION", False);
    event.data.l[3] = 1;
    XSendEvent(_display, DefaultRootWindow(_display), False,
               SubstructureNotifyMask | SubstructureRedirectMask,
               (XEvent *) &event);
    XFlush(_display);
}

- (void) setOpaque: (BOOL) value {
    _isOpaque = value;
}

- (void) sheetOrderFrontFromFrame: (NSRect) frame
                      aboveWindow: (CGWindow *) aboveWindow
{
    [self setFrame: frame];
    [self placeAboveWindow: [aboveWindow windowNumber]];
}

- (void) sheetOrderOutToFrame: (NSRect) frame {
    [self hideWindow];
}

- (void) showWindowForAppActivation: (O2Rect) frame {
    [self showWindowWithoutActivation];
}

- (void) hideWindowForAppDeactivation: (O2Rect) frame {
    /* Ignored */
}

- (void) hideWindow {
    XUnmapWindow(_display, _window);
    _mapped = NO;
}

- (void) placeAboveWindow: (NSInteger) otherNumber {
    X11Window *other = [X11Window windowWithWindowNumber: otherNumber];
    [self ensureMapped];

    if (!other) {
        XRaiseWindow(_display, _window);
    } else {
        Window w[2] = {_window, other->_window};
        XRestackWindows(_display, w, 1);
    }
}

- (void) placeBelowWindow: (NSInteger) otherNumber {
    X11Window *other = [X11Window windowWithWindowNumber: otherNumber];
    [self ensureMapped];

    if (!other) {
        XLowerWindow(_display, _window);
    } else {
        Window w[2] = {other->_window, _window};
        XRestackWindows(_display, w, 1);
    }
}

- (void) makeKey {
    [self ensureMapped];
    XRaiseWindow(_display, _window);
    Atom activeAtom = XInternAtom(_display, "_NET_ACTIVE_WINDOW", False);
    XEvent act = {0};
    act.xclient.type = ClientMessage;
    act.xclient.window = _window;
    act.xclient.message_type = activeAtom;
    act.xclient.format = 32;
    act.xclient.data.l[0] = 1;
    act.xclient.data.l[1] = CurrentTime;
    XSendEvent(_display, DefaultRootWindow(_display), False,
               SubstructureRedirectMask | SubstructureNotifyMask, &act);
    XSetInputFocus(_display, _window, RevertToPointerRoot, CurrentTime);
    XFlush(_display);
}

- (void) makeMain {
}

- (void) captureEvents {
}

- (void) miniaturize {
    XIconifyWindow(_display, _window, DefaultScreen(_display));
}

- (void) deminiaturize {
    XRaiseWindow(_display, _window);
}

/* darling-lol: AppKit asks every window whether it is miniaturized on every event poll (NSWindow
 * _makeSureIsOnAScreen), and each answer was a synchronous X round trip (XGetWindowProperty): about 13 blocking waits
 * per game frame. Reuse the answer for 100 ms per window. */
#include <mach/mach_time.h>
#define RCLOL_MINI_SLOTS 32
static struct { Window window; uint64_t stamp; BOOL value; } rclolMini[RCLOL_MINI_SLOTS];

- (BOOL) isMiniaturized {
    static mach_timebase_info_data_t tb;
    if (tb.denom == 0) mach_timebase_info(&tb);
    uint64_t now = mach_absolute_time();
    unsigned slot = (unsigned) (_window % RCLOL_MINI_SLOTS);
    if (rclolMini[slot].window == _window && rclolMini[slot].stamp != 0 &&
        (now - rclolMini[slot].stamp) * tb.numer / tb.denom < 100000000ULL)
        return rclolMini[slot].value;
    BOOL value = [self rclolQueryMiniaturized];
    rclolMini[slot].window = _window;
    rclolMini[slot].value = value;
    rclolMini[slot].stamp = now;
    return value;
}

- (BOOL) rclolQueryMiniaturized {
    Atom wmState = XInternAtom(_display, "_NET_WM_STATE", FALSE);
    Atom hiddenState = XInternAtom(_display, "_NET_WM_STATE_HIDDEN", FALSE);

    Atom type;
    int format;
    unsigned long nItem, bytesAfter;
    unsigned char *properties = NULL;
    BOOL rv = NO;

    if (XGetWindowProperty(_display, _window, wmState, 0, (~0L), FALSE, XA_ATOM,
                           &type, &format, &nItem, &bytesAfter,
                           &properties) == Success) {
        Atom *atoms = (Atom *) properties;
        for (int i = 0; i < nItem; i++) {
            if (atoms[i] == hiddenState) {
                rv = YES;
                break;
            }
        }
        XFree(properties);
    }

    return rv;
}

- (CGLContextObj) cglContext {
    return _cglContext;
}

- (void) createCGLContextObjIfNeeded {
    if (_cglContext == NULL) {
        CGLError error;

        if ((error = CGLCreateContext(NULL, NULL, &_cglContext)) !=
            kCGLNoError) {
            NSLog(@"CGLCreateContext failed at %s %d with error %d", __FILE__,
                  __LINE__, error);

            [NSException raise: NSGenericException
                        format: @"Failed to create GL context, CGL error %d",
                                error];
        }
        if ((error = CGLContextMakeCurrentAndAttachToWindow(
                     _cglContext, _cglWindow)) != kCGLNoError)
            NSLog(@"CGLContextMakeCurrentAndAttachToWindow failed with error "
                  @"%d",
                  error);
    }
    if (_cglContext != nil && _caContext == nil) {
        _caContext =
                [[CAWindowOpenGLContext alloc] initWithCGLContext: _cglContext];
    }
}

- (void) openGLFlushBuffer {
    /* A remote compositor surface owns this drawable while it is present.
     * Swapping the local Onyx surface would erase it until the next timer
     * tick. Keep local presentation for windows without a usable remote frame. */
    if ([self presentRemoteCAFrame: nil])
        return;

    CGLError error;

    CGLContextObj prevContext = CGLGetCurrentContext();

    [self createCGLContextObjIfNeeded];
    if (_caContext == nil)
        return;

    O2Surface *surface = [_context surface];
    size_t width = O2ImageGetWidth(surface);
    size_t height = O2ImageGetHeight(surface);

    [_caContext prepareViewportWidth: width height: height];
    [_caContext renderSurface: surface];

    glFlush();
    CGLFlushDrawable(_cglContext);

    CGLSetCurrentContext(prevContext);
}

- (void) flushBuffer {
    if (_context == nil)
        return;
    O2ContextFlush(_context);
    [self openGLFlushBuffer];
}

- (void) setLastKnownCursorPosition: (CGPoint) point {
    _lastMotionPos = [self transformPoint: point];
}

- (NSPoint) mouseLocationOutsideOfEventStream {
    return [self transformPoint: _lastMotionPos];
}

- (O2Rect) frame {
    return [(X11Display *) [NSDisplay currentDisplay] frameForRootRect: _frame];
}

static int ignoreBadWindow(Display *display, XErrorEvent *errorEvent) {
    if (errorEvent->error_code == BadWindow)
        return 0;
    char buf[512];
    XGetErrorText(display, errorEvent->error_code, buf, 512);
    [NSException raise: NSInternalInconsistencyException
                format: @"X11 error: %s", buf];
    return 0;
}

- (void) frameChanged {
    _remoteFrameTargetRefresh = 0;
    XErrorHandler previousHandler = XSetErrorHandler(ignoreBadWindow);
    @try {
        Window root, parent;
        Window window = _window;
        int x, y;
        unsigned int w, h, d, b, nchild;
        Window *children;
        O2Rect rect = NSZeroRect;
        // recursively get geometry to get absolute position
        BOOL success = YES;
        while (window && success) {
            XGetGeometry(_display, window, &root, &x, &y, &w, &h, &b, &d);
            success = XQueryTree(_display, window, &root, &parent, &children,
                                 &nchild);
            if (children)
                XFree(children);

            // first iteration: save our own w, h
            if (window == _window)
                rect = NSMakeRect(0, 0, w, h);
            rect.origin.x += x;
            rect.origin.y += y;
            window = parent;
        };

        [self invalidateContextWithNewSize: rect.size];
        _frame = rect;
    } @finally {
        XSetErrorHandler(previousHandler);
    }
}

- (Visual *) visual {
    return DefaultVisual(_display, DefaultScreen(_display));
}

- (Drawable) drawable {
    return _window;
}

- (void) addEntriesToDeviceDictionary: (NSDictionary *) entries {
    [_deviceDictionary addEntriesFromDictionary: entries];
}

- (NSPoint) transformPoint: (NSPoint) pos; {
    return NSMakePoint(pos.x, _frame.size.height - pos.y);
}

- (X11SubWindow *) createSubWindowWithFrame: (CGRect) frame {
    return [[[X11SubWindow alloc] initWithParentWindow: self
                                                 frame: frame] autorelease];
}

@end
