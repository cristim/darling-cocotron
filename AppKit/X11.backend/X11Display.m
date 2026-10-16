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

#import "X11Display.h"
#import "NSEvent_mouse.h"
#import "X11Cursor.h"
#import "X11Pasteboard.h"
#import "X11Window.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSScreen.h>
#import <Foundation/NSDebug.h>

#ifndef DARLING
#import <Foundation/NSSelectInputSource.h>
#import <Foundation/NSSocket_bsd.h>
#endif

#import <AppKit/NSColor.h>
#import <AppKit/NSCursor.h>
#import <AppKit/NSFontManager.h>
#import <AppKit/NSFontTypeface.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSWindow.h>

#import <Onyx2D/O2Font_freetype.h>

#import <OpenGL/CGLInternal.h>

#import "CarbonKeys.h"
#import "X11KeySymToUCS.h"
#import <X11/XKBlib.h>
#import <X11/Xutil.h>
#import <X11/Xatom.h>
#import <X11/extensions/XKBrules.h>
#import <X11/extensions/Xrandr.h>
#import <X11/keysym.h>
#import <fcntl.h>
#import <fontconfig/fontconfig.h>
#import <stddef.h>
#include <stdlib.h>

void NSColorSetCatalogColor(NSColorListName catalogName, NSColorName colorName, NSColor *color);

@implementation X11Display

static int errorHandler(Display *display, XErrorEvent *errorEvent) {
    return [(X11Display *) [X11Display currentDisplay] handleError: errorEvent];
}

#ifdef DARLING
static void socketCallback(CFSocketRef s, CFSocketCallBackType type,
                           CFDataRef address, const void *data, void *info)
{
    X11Display *self = info;
    [self processPendingEvents];
}
#endif

- init {
    if (self = [super init]) {

#ifdef DARLING
        // EGL also uses this Display from compositor threads. Enable Xlib's
        // connection locks before opening it or issuing any Xlib requests.
        if (!XInitThreads()) {
            NSLog(@"Unable to initialize Xlib thread support");
            [self release];
            return nil;
        }
#endif
        _display = XOpenDisplay(NULL);

        if (_display == NULL) {
            _display = XOpenDisplay(":0");
        }

        if (_display == NULL) {
            // Failed to connect.
            [self release];
            return nil;
        }

        if (NSDebugEnabled)
            XSynchronize(_display, True);

        XSetErrorHandler(errorHandler);

        _fileDescriptor = ConnectionNumber(_display);
#ifndef DARLING
        _inputSource = [[NSSelectInputSource
                socketInputSourceWithSocket:
                        [NSSocket_bsd socketWithDescriptor: _fileDescriptor]]
                retain];
        [_inputSource setDelegate: self];
        [_inputSource setSelectEventMask: NSSelectReadEvent];
#else
        // There's no need to retain/release the display,
        // because the display is guaranteed to outlive
        // the socket.
        CFSocketContext context = {.version = 0,
                                   .info = self,
                                   .retain = NULL,
                                   .release = NULL,
                                   .copyDescription = NULL};
        _cfSocket = CFSocketCreateWithNative(
                kCFAllocatorDefault, _fileDescriptor, kCFSocketReadCallBack,
                socketCallback, &context);
        _source =
                CFSocketCreateRunLoopSource(kCFAllocatorDefault, _cfSocket, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), _source, kCFRunLoopCommonModes);

        CGLRegisterNativeDisplay(_display);
#endif

        _windowsByID = [NSMutableDictionary new];
        [self _enableDetectableAutoRepeat];

        XSetLocaleModifiers("");
        _xim = XOpenIM(_display, NULL, NULL, NULL);

        if (!_xim) {
            NSLog(@"Failed to open XIM, falling back to im=none\n");

            XSetLocaleModifiers("@im=none");
            _xim = XOpenIM(_display, NULL, NULL, NULL);
        }

        int errorBase;
        if (XRRQueryExtension(_display, &_rrEventBase, &errorBase)) {
            XRRSelectInput(_display, DefaultRootWindow(_display), RRScreenChangeNotifyMask | RRCrtcChangeNotifyMask | RROutputChangeNotifyMask | RROutputPropertyNotifyMask);
        }

        lastFocusedWindow = nil;
        lastClickTimeStamp = 0.0;
        clickCount = 0;
    }
    return self;
}

- (void) dealloc {
    [_blankCursor release];
    [_defaultCursor release];

    if (_xim)
        XCloseIM(_xim);

    if (_display)
        XCloseDisplay(_display);
#ifdef DARLING
    if (_source != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), _source, kCFRunLoopCommonModes);
        CFRelease(_source);
    }
    if (_cfSocket != NULL)
        CFRelease(_cfSocket);
#endif

    [_windowsByID release];
    [super dealloc];
}

- (CGWindow *) newWindowWithDelegate: (NSWindow *) delegate {
    return [[X11Window alloc] initWithDelegate: delegate];
}

- (Display *) display {
    return _display;
}

- (BOOL) activateProcessIdentifier: (pid_t) processIdentifier {
    if (!_display || processIdentifier <= 0) return NO;

    Window root = DefaultRootWindow(_display), parent = None;
    Window *children = NULL;
    unsigned int count = 0;
    if (!XQueryTree(_display, root, &root, &parent, &children, &count))
        return NO;

    Atom pidAtom = XInternAtom(_display, "_NET_WM_PID", False);
    Atom activeAtom = XInternAtom(_display, "_NET_ACTIVE_WINDOW", False);
    BOOL activated = NO;
    for (unsigned int index = count; index > 0; --index) {
        Window window = children[index - 1];
        Atom actualType = None;
        int actualFormat = 0;
        unsigned long items = 0, remaining = 0;
        unsigned char *value = NULL;
        int status = XGetWindowProperty(_display, window, pidAtom, 0, 1, False,
                                        XA_CARDINAL, &actualType, &actualFormat,
                                        &items, &remaining, &value);
        BOOL matches = status == Success && actualType == XA_CARDINAL &&
                       actualFormat == 32 && items == 1 && value &&
                       *(unsigned long *)value == (unsigned long)processIdentifier;
        if (value) XFree(value);
        if (!matches) continue;

        XWindowAttributes attributes;
        if (!XGetWindowAttributes(_display, window, &attributes) ||
            attributes.map_state != IsViewable) continue;

        XEvent event = {0};
        event.xclient.type = ClientMessage;
        event.xclient.window = window;
        event.xclient.message_type = activeAtom;
        event.xclient.format = 32;
        event.xclient.data.l[0] = 1;
        event.xclient.data.l[1] = CurrentTime;
        XSendEvent(_display, root, False,
                   SubstructureRedirectMask | SubstructureNotifyMask, &event);
        XRaiseWindow(_display, window);
        XSetInputFocus(_display, window, RevertToPointerRoot, CurrentTime);
        XFlush(_display);
        activated = YES;
        break;
    }
    if (children) XFree(children);
    return activated;
}

- (void) _enableDetectableAutoRepeat {
    int major = XkbMajorVersion, minor = XkbMinorVersion;
    XkbStateRec state;

    if (!XkbLibraryVersion(&major, &minor))
        return;
    if (!XkbQueryExtension(_display, NULL, NULL, &major, &minor, NULL))
        return;
    
    Bool supported;
    XkbSetDetectableAutoRepeat(_display, TRUE, &supported);
}

- (void) _invalidateRRCache {
    if (_lastScreens) {
        [_lastScreens release];
        _lastScreens = nil;
    }
}

- (NSArray *) screens {

    NSArray* last = [_lastScreens retain];
    if (last) {
        return [last autorelease];
    }

    int eventBase, errorBase;

    if (XRRQueryExtension(_display, &eventBase, &errorBase)) {
        XRRScreenResources *screen;

        screen = XRRGetScreenResources(_display, DefaultRootWindow(_display));
        NSMutableArray<NSScreen *> *retval =
                [NSMutableArray arrayWithCapacity: screen->noutput];

        Atom edidAtom = XInternAtom(_display, "EDID", FALSE);

        for (int i = 0; i < screen->noutput; i++) {
            XRROutputInfo *oinfo =
                    XRRGetOutputInfo(_display, screen, screen->outputs[i]);
            NSScreen *nsscreen;

            if (oinfo->crtc) {
                XRRCrtcInfo *crtc =
                        XRRGetCrtcInfo(_display, screen, oinfo->crtc);
                NSRect frame =
                        NSMakeRect(crtc->x, crtc->y, crtc->width, crtc->height);

                nsscreen =
                        [[[NSScreen alloc] initWithFrame: frame
                                            visibleFrame: frame] autorelease];

                Atom actualType;
                unsigned long nitems, bytesAfter;
                int actualFormat;
                unsigned char *prop;

                if (XRRGetOutputProperty(_display, screen->outputs[i], edidAtom,
                                         0, 100, FALSE, FALSE, AnyPropertyType,
                                         &actualType, &actualFormat, &nitems,
                                         &bytesAfter, &prop) == Success) {
                    if (prop && nitems > 0)
                        [nsscreen setEdid: [NSData dataWithBytes: prop
                                                          length: nitems]];
                }

                XRRFreeCrtcInfo(crtc);
            } else {
                nsscreen = [[[NSScreen alloc] initWithFrame: NSZeroRect
                                               visibleFrame: NSZeroRect]
                        autorelease];
            }
            [nsscreen setCgDirectDisplayID: (i + 1)];

            [retval addObject: nsscreen];

            XRRFreeOutputInfo(oinfo);
        }

        XRRFreeScreenResources(screen);

        NSArray* array = [NSArray arrayWithArray: retval];
        _lastScreens = [array retain];
        return array;
    } else {
        NSRect frame = NSMakeRect(
                0, 0, DisplayWidth(_display, DefaultScreen(_display)),
                DisplayHeight(_display, DefaultScreen(_display)));
        return [NSArray
                arrayWithObject: [[[NSScreen alloc] initWithFrame: frame
                                                     visibleFrame: frame]
                                         autorelease]];
    }
}

static NSDictionary *modeInfoToDictionary(const XRRModeInfo *mi, int depth) {
    double rate = 0;

    if (mi->hTotal && mi->vTotal)
        rate = (double) mi->dotClock /
               ((double) mi->hTotal * (double) mi->vTotal);

    return @{
        @"Width" : @(mi->width),
        @"Height" : @(mi->height),
        @"Depth" : @(depth),
        @"RefreshRate" : @(rate)
    };
}

- (NSArray *) modesForScreen: (int) screenIndex {
    int eventBase, errorBase;
    const int defaultDepth =
            XDefaultDepthOfScreen(XDefaultScreenOfDisplay(_display));

    if (!XRRQueryExtension(_display, &eventBase, &errorBase)) {
        Screen *defaultScreen = XDefaultScreenOfDisplay(_display);
        return @[ @{
            @"Width" : @(WidthOfScreen(defaultScreen)),
            @"Height" : @(HeightOfScreen(defaultScreen)),
            @"Depth" : @(defaultDepth)
        } ];
    } else {
        XRRScreenResources *screen =
                XRRGetScreenResources(_display, DefaultRootWindow(_display));

        if (screenIndex < 0 || screenIndex >= screen->noutput) {
            XRRFreeScreenResources(screen);
            return nil;
        }

        XRROutputInfo *oinfo = XRRGetOutputInfo(_display, screen,
                                                screen->outputs[screenIndex]);

        NSMutableArray<NSDictionary *> *retval =
                [NSMutableArray arrayWithCapacity: oinfo->nmode];

        for (int i = 0; i < oinfo->nmode; i++) {
            XRRModeInfo *mode = NULL;
            for (int j = 0; j < screen->nmode; j++) {
                if (screen->modes[j].id == oinfo->modes[i]) {
                    mode = &screen->modes[j];
                    break;
                }
            }

            if (mode != NULL) {
                NSDictionary *dict = modeInfoToDictionary(mode, defaultDepth);
                [retval addObject: dict];
            }
        }

        XRRFreeOutputInfo(oinfo);
        XRRFreeScreenResources(screen);
        return [NSArray arrayWithArray: retval];
    }
}

- (BOOL) setMode: (NSDictionary *) mode forScreen: (int) screenIndex {
    int eventBase, errorBase;

    if (XRRQueryExtension(_display, &eventBase, &errorBase)) {
        // TODO: Use XRRSetCrtcConfig
        // https://cgit.freedesktop.org/xorg/lib/libXrandr/tree/include/X11/extensions/Xrandr.h#n283
    }

    return FALSE;
}

- (NSDictionary *) currentModeForScreen: (int) screenIndex {
    int eventBase, errorBase;
    NSDictionary *dict = @{};

    if (XRRQueryExtension(_display, &eventBase, &errorBase)) {
        XRRScreenResources *screen =
                XRRGetScreenResources(_display, DefaultRootWindow(_display));

        if (screenIndex < 0 || screenIndex >= screen->noutput) {
            XRRFreeScreenResources(screen);
            return dict;
        }

        XRROutputInfo *oinfo = XRRGetOutputInfo(_display, screen,
                                                screen->outputs[screenIndex]);

        if (oinfo->crtc) {
            XRRCrtcInfo *crtc = XRRGetCrtcInfo(_display, screen, oinfo->crtc);

            for (int i = 0; i < screen->nmode; i++) {
                if (screen->modes[i].id == crtc->mode) {
                    const int defaultDepth = XDefaultDepthOfScreen(
                            XDefaultScreenOfDisplay(_display));
                    dict = modeInfoToDictionary(&screen->modes[i],
                                                defaultDepth);

                    break;
                }
            }

            XRRFreeCrtcInfo(crtc);
        }

        XRRFreeOutputInfo(oinfo);
        XRRFreeScreenResources(screen);
    }
    return dict;
}

- (int) keyboardLayoutId {
    int major = XkbMajorVersion, minor = XkbMinorVersion;
    XkbStateRec state;

    if (!XkbLibraryVersion(&major, &minor))
        return -1;
    if (!XkbQueryExtension(_display, NULL, NULL, &major, &minor, NULL))
        return -1;
    if (XkbGetState(_display, XkbUseCoreKbd, &state) == Success)
        return state.group;

    return -1;
}

- (void) keyboardLayoutName: (NSString **) name
                   fullName: (NSString **) fullName
{
    int major = XkbMajorVersion, minor = XkbMinorVersion;

    if (name)
        *name = @"?";
    if (fullName)
        *fullName = @"?";

    if (!XkbLibraryVersion(&major, &minor))
        return;
    if (!XkbQueryExtension(_display, NULL, NULL, &major, &minor, NULL))
        return;

    XkbStateRec state;
    if (XkbGetState(_display, XkbUseCoreKbd, &state) != Success)
        return;

    XkbDescPtr desc =
            XkbGetKeyboard(_display, XkbAllComponentsMask, XkbUseCoreKbd);
    if (!desc)
        return;

    if (fullName != NULL) {
        char *group = XGetAtomName(_display, desc->names->groups[state.group]);

        if (group != NULL) {
            *fullName = [NSString stringWithUTF8String: group];
            XFree(group);
        }
    }

    XkbRF_VarDefsRec vd;
    if (name != NULL && XkbRF_GetNamesProp(_display, NULL, &vd)) {
        char *saveptr;
        char *tok = strtok_r(vd.layout, ",", &saveptr);

        for (int i = 0; i < state.group; i++) {
            tok = strtok_r(NULL, ",", &saveptr);
            if (tok == NULL)
                break;
        }

        if (tok != NULL) {
            *name = [NSString stringWithUTF8String: tok];
        }
    }
}

- (UCKeyboardLayout *) keyboardLayout: (uint32_t *) byteLength {
    int major = XkbMajorVersion, minor = XkbMinorVersion;
    XkbDescPtr pKBDesc;
    unsigned char group = 0;
    XkbStateRec state;

    struct MyLayout {
        UCKeyboardLayout layout;
        UCKeyModifiersToTableNum modifierVariants;
        UInt8 secondTableNum, thirdTableNum;
        UCKeyToCharTableIndex tableIndex;
        UInt32 secontTableOffset;
        UCKeyOutput table1[128];
        UCKeyOutput table2[128];
    };

    if (byteLength)
        *byteLength = 0;

    if (!XkbLibraryVersion(&major, &minor))
        return NULL;
    if (!XkbQueryExtension(_display, NULL, NULL, &major, &minor, NULL))
        return NULL;

    pKBDesc = XkbGetMap(_display, XkbAllClientInfoMask, XkbUseCoreKbd);
    if (!pKBDesc)
        return NULL;

    if (XkbGetState(_display, XkbUseCoreKbd, &state) == Success)
        group = state.group;

    struct MyLayout *layout =
            (struct MyLayout *) malloc(sizeof(struct MyLayout));

    layout->layout.keyLayoutHeaderFormat = kUCKeyLayoutHeaderFormat;
    layout->layout.keyLayoutDataVersion = 0;
    layout->layout.keyLayoutFeatureInfoOffset = 0;
    layout->layout.keyboardTypeCount = 1;

    memset(layout->layout.keyboardTypeList, 0, sizeof(UCKeyboardTypeHeader));

    layout->layout.keyboardTypeList[0].keyModifiersToTableNumOffset =
            offsetof(struct MyLayout, modifierVariants);
    layout->layout.keyboardTypeList[0].keyToCharTableIndexOffset =
            offsetof(struct MyLayout, tableIndex);

    layout->modifierVariants.keyModifiersToTableNumFormat =
            kUCKeyModifiersToTableNumFormat;
    layout->modifierVariants.defaultTableNum = 0;
    layout->modifierVariants.modifiersCount = 3;
    layout->modifierVariants.tableNum[0] = 0;
    layout->modifierVariants.tableNum[1] = 0; // cmd key bit
    layout->modifierVariants.tableNum[2] = 1; // shift key bit

    layout->tableIndex.keyToCharTableIndexFormat = kUCKeyToCharTableIndexFormat;
    layout->tableIndex.keyToCharTableSize = 128;
    layout->tableIndex.keyToCharTableCount = 2;
    layout->tableIndex.keyToCharTableOffsets[0] =
            offsetof(struct MyLayout, table1);
    layout->tableIndex.keyToCharTableOffsets[1] =
            offsetof(struct MyLayout, table2);

    for (int shift = 0; shift <= 1; shift++) {
        UCKeyOutput *outTable = (shift == 0) ? layout->table1 : layout->table2;
        for (int i = 0; i < 128; i++) {
            // Reverse the operation we do in -postXEvent:
            const int x11KeyCode = carbonToX11[i];

            if (!x11KeyCode) {
                outTable[i] = 0;
                continue;
            }

            // NOTE: Not using the group here. It just works with 0 instead...
            KeySym sym = XkbKeycodeToKeysym(_display, x11KeyCode, 0, shift);

            if (sym != NoSymbol)
                outTable[i] = X11KeySymToUCS(sym);
            else
                outTable[i] = 0;
        }
    }

    XkbFreeClientMap(pKBDesc, XkbAllClientInfoMask, true);

    if (byteLength)
        *byteLength = sizeof(struct MyLayout);

    return &layout->layout;
}

/* darling-lol: the game asks for the pointer position, the pressed buttons and the modifier state about a thousand
 * times per second. Each answer was a synchronous X round trip (XQueryPointer / XkbGetState) that puts the main thread
 * to sleep until XWayland replies; while the mouse moves they dominated the slow frames. Reuse a reply for 8 ms, keep it
 * current from the input events themselves (a motion event carries position and button state), and drop it on every
 * button, key, crossing or focus event so the next question after a state change is always asked for real. */
#include <mach/mach_time.h>
static BOOL rclolFresh(uint64_t *stamp) {
    static mach_timebase_info_data_t tb;
    if (tb.denom == 0) mach_timebase_info(&tb);
    uint64_t now = mach_absolute_time();
    if (*stamp != 0 && (now - *stamp) * tb.numer / tb.denom < 8000000ULL) return YES;
    *stamp = now;
    return NO;
}
static uint64_t rclolPointerStamp, rclolModsStamp;
static int rclolRootX, rclolRootY;
static unsigned int rclolPointerState;
static NSUInteger rclolMods;
static BOOL rclolQueryPointer(Display *display) {
    if (rclolFresh(&rclolPointerStamp)) return YES;
    for (int screen = 0; screen < ScreenCount(display); ++screen) {
        Window root, child;
        int windowX, windowY;
        if (XQueryPointer(display, RootWindow(display, screen), &root, &child, &rclolRootX, &rclolRootY,
                          &windowX, &windowY, &rclolPointerState))
            return YES;
    }
    rclolPointerStamp = 0;
    return NO;
}

- (NSUInteger) currentModifierFlags {
    if (rclolFresh(&rclolModsStamp)) return rclolMods;
    XkbStateRec r;
    if (XkbGetState(_display, XkbUseCoreKbd, &r) != Success) {
        rclolModsStamp = 0;
        return 0;
    }
    return rclolMods = [self modifierFlagsForState: r.mods];
}

- (NSUInteger) pressedMouseButtons {
    if (!rclolQueryPointer(_display)) return 0;
    unsigned int state = rclolPointerState;
    // AppKit numbers left/right/middle as 0/1/2; X11 uses 1/3/2.
    return ((state & Button1Mask) ? 1u : 0u) | ((state & Button3Mask) ? 2u : 0u) | ((state & Button2Mask) ? 4u : 0u);
}

- (NSPasteboard *) pasteboardWithName: (NSString *) name {
    return [X11Pasteboard pasteboardWithName: name];
}

- (NSDraggingManager *) draggingManager {
    //   NSUnimplementedMethod();
    return nil;
}

- (NSColor *) colorWithName: (NSString *) colorName {
    if ([colorName isEqual: @"controlColor"])
        return [NSColor colorWithCalibratedWhite: 0.93 alpha: 1.0];
    if ([colorName isEqual: @"disabledControlTextColor"])
        return [NSColor grayColor];
    if ([colorName isEqual: @"controlTextColor"])
        return [NSColor blackColor];
    if ([colorName isEqual: @"menuBackgroundColor"])
        return [NSColor colorWithCalibratedWhite: 0.9 alpha: 1.0];
    if ([colorName isEqual: @"mainMenuBarColor"])
        return [NSColor colorWithCalibratedWhite: 0.9 alpha: 1.0];
    if ([colorName isEqual: @"controlShadowColor"])
        return [NSColor darkGrayColor];
    if ([colorName isEqual: @"selectedControlColor"])
        return [NSColor blueColor];
    if ([colorName isEqual: @"controlBackgroundColor"])
        return [NSColor whiteColor];
    if ([colorName isEqual: @"controlLightHighlightColor"])
        return [NSColor lightGrayColor];
    if ([colorName isEqual: @"headerColor"])
        return [NSColor greenColor];
    if ([colorName isEqual: @"textBackgroundColor"])
        return [NSColor whiteColor];
    if ([colorName isEqual: @"textColor"])
        return [NSColor blackColor];
    if ([colorName isEqual: @"selectedTextColor"])
        return [NSColor whiteColor];
    if ([colorName isEqual: @"headerTextColor"])
        return [NSColor blackColor];
    if ([colorName isEqual: @"menuItemTextColor"])
        return [NSColor blackColor];
    if ([colorName isEqual: @"selectedMenuItemTextColor"])
        return [NSColor whiteColor];
    if ([colorName isEqual: @"selectedMenuItemColor"])
        return [NSColor blueColor];
    if ([colorName isEqual: @"selectedControlTextColor"])
        return [NSColor blackColor];
    if ([colorName isEqual: @"windowFrameColor"])
        return [NSColor lightGrayColor];
    if ([colorName isEqual: @"shadowColor"])
        return [NSColor colorWithGenericGamma22White: 0.0f alpha: 1.0f];
    if ([colorName isEqual: @"alternateSelectedControlTextColor"])
        return [NSColor colorWithGenericGamma22White: 1.0f alpha: 1.0f];
    if ([colorName isEqual: @"labelColor"])
        return [NSColor colorWithSRGBRed: 0.0f
                                   green: 0.0f
                                    blue: 0.0f
                                   alpha: 0.847059f];
    if ([colorName isEqual: @"linkColor"])
        return [NSColor colorWithSRGBRed: 0.0f
                                   green: 0.411765f
                                    blue: 0.850980f
                                   alpha: 1.0f];
    if ([colorName isEqual: @"unemphasizedSelectedTextColor"])
        return [NSColor
                colorWithGenericGamma22White: 0.0f /* 1.0f on dark mode */
                                               alpha: 1.0f];
    if ([colorName isEqual: @"selectedContentBackgroundColor"])
        return [NSColor colorWithSRGBRed: 0.0f
                                   green: 0.388235f /* 0.345098f on dark mode */
                                    blue: 0.882353f /* 0.815686f on dark mode */
                                   alpha: 1.0f];
    if ([colorName isEqual: @"unemphasizedSelectedContentBackgroundColor"])
        return [NSColor colorWithSRGBRed: 0.862745f /* 0.274510f on dark mode */
                                   green: 0.862745f /* 0.274510f on dark mode */
                                    blue: 0.862745f /* 0.274510f on dark mode */
                                   alpha: 1.0f];
    if ([colorName isEqual: @"alternatingContentBackgroundColor"])
        return [NSColor colorWithSRGBRed: 0.956863f
                                   green: 0.960784f
                                    blue: 0.960784f
                                   alpha: 1.0f];
    if ([colorName isEqual: @"selectedTextBackgroundColor"])
        return [NSColor colorWithCalibratedRed: 0.20f
                                         green: 0.55f
                                          blue: 1.00f
                                         alpha: 1.00f];
    if ([colorName isEqual: @"alternateSelectedControlColor"])
        return [NSColor colorWithSRGBRed: 0.0f
                                   green: 0.411765f
                                    blue: 0.850980f
                                    alpha: 1.0f];
    if ([colorName isEqual: @"controlDarkShadowColor"])
        return [NSColor colorWithCalibratedRed: 0.0f
                                         green: 0.0f
                                          blue: 0.0f
                                         alpha: 1.0f];
    if ([colorName isEqual: @"controlHighlightColor"])
        return [NSColor colorWithCalibratedRed: 0.890097f
                                         green: 0.890097f
                                          blue: 0.890097f
                                         alpha: 1.0f];
    if ([colorName isEqual: @"gridColor"])
        return [NSColor colorWithGenericGamma22White: 0.80f alpha: 1.0f];
    if ([colorName isEqual: @"highlightColor"])
        return [NSColor colorWithGenericGamma22White: 1.0f alpha: 1.0f];
    if ([colorName isEqual: @"keyboardFocusIndicatorColor"])
        return [NSColor colorWithSRGBRed: 0.231373f
                                   green: 0.60f
                                    blue: 0.988235f
                                    alpha: 1.0f];
    if ([colorName isEqual: @"knobColor"])
        return [NSColor colorWithSRGBRed: 0.60f
                                   green: 0.60f
                                    blue: 0.733333f
                                    alpha: 1.0f];
    if ([colorName isEqual: @"scrollBarColor"])
        return [NSColor colorWithSRGBRed: 0.666667f
                                   green: 0.666667f
                                    blue: 0.666667f
                                    alpha: 1.0f];
    if ([colorName isEqual: @"secondarySelectedControlColor"])
        return [NSColor colorWithSRGBRed: 0.862745f
                                   green: 0.862745f
                                    blue: 0.862745f
                                    alpha: 1.0f];
    if ([colorName isEqual: @"selectedKnobColor"])
        return [NSColor colorWithSRGBRed: 0.40f
                                   green: 0.40f
                                    blue: 0.60f
                                    alpha: 1.0f];

    if ([colorName isEqual: @"controlAccentBlueColor"])
        /* darling-lol: macOS 10.14+ system accent blue (sRGB 0,122,255);
         * Chromium queries it during UI setup and previously fell back to
         * red. */
        return [NSColor colorWithSRGBRed: 0.0f
                                   green: 0.478431f
                                    blue: 1.0f
                                   alpha: 1.0f];

    NSLog(@"missing color for %@", colorName);
    return [NSColor redColor];
}

- (void) _addSystemColor: (NSColor *) result forName: (NSString *) colorName {
    NSColorSetCatalogColor(@"System", colorName, result);
}

- (NSTimeInterval) textCaretBlinkInterval {
    return 0.5;
}

- (void) hideCursor {
    if (!_blankCursor)
        _blankCursor = [[X11Cursor alloc] initBlank];
    [self setCursor: _blankCursor];
}

- (void) unhideCursor {
    NSCursor *current = [NSCursor currentCursor];
    if (current != nil) {
        [current push];
        [current pop];
    } else {
        if (!_defaultCursor)
            _defaultCursor = [[X11Cursor alloc] init];
        [self setCursor: _defaultCursor];
    }
}

// Arrow, IBeam, HorizontalResize, VerticalResize
- (id) cursorWithName: (NSString *) name {
    unsigned int shape = XC_left_ptr;
    const char *xname = "left_ptr";

    if ([name isEqualToString: @"arrowCursor"])
        xname = "left_ptr";
    else if ([name isEqualToString: @"closedHandCursor"])
        xname = "hand3";
    else if ([name isEqualToString: @"crosshairCursor"])
        xname = "crosshair";
    // else if([name isEqualToString:@"disappearingItemCursor"])
    // shape = XC_left_ptr;
    else if ([name isEqualToString: @"IBeamCursor"])
        xname = "xterm";
    else if ([name isEqualToString: @"openHandCursor"])
        xname = "fleur";
    else if ([name isEqualToString: @"pointingHandCursor"])
        xname = "hand";
    else if ([name isEqualToString: @"resizeDownCursor"])
        xname = "bottom_side";
    else if ([name isEqualToString: @"resizeLeftCursor"])
        xname = "left_side";
    else if ([name isEqualToString: @"resizeLeftRightCursor"])
        xname = "h_double_arrow";
    else if ([name isEqualToString: @"resizeRightCursor"])
        xname = "right_side";
    else if ([name isEqualToString: @"resizeUpCursor"])
        xname = "top_side";
    else if ([name isEqualToString: @"resizeUpDownCursor"])
        xname = "v_double_arrow";

    return [[[X11Cursor alloc] initWithName: xname] autorelease];
}

- (id) cursorWithImage: (NSImage *) image hotSpot: (NSPoint) hotSpot {
    return [[[X11Cursor alloc] initWithImage: image
                                    hotPoint: hotSpot] autorelease];
}

- (void) setCursor: (id) cursor {
    CGWindow *window = [[NSApp keyWindow] platformWindow];
    if (window != nil) {
        Window w = [(X11Window *) window windowHandle];
        Cursor c = ((X11Cursor *) cursor).cursor;

        XDefineCursor(_display, w, c);
        /* Send cursor changes immediately without waiting for an X server
         * reply on the input thread. X requests on this connection remain
         * ordered; no server result is consumed here. */
        XFlush(_display);
    }
}

- (void) beep {
    XBell(_display, 100);
}

- (NSSet *) allFontFamilyNames {
    FcPattern *pat = FcPatternCreate();
    FcObjectSet *props = FcObjectSetBuild(FC_FAMILY, NULL);

    FcFontSet *set = FcFontList(O2FontSharedFontConfig(), pat, props);
    NSMutableSet *ret = [NSMutableSet set];

    for (int i = 0; i < set->nfont; i++) {
        FcChar8 *family;
        if (FcPatternGetString(set->fonts[i], FC_FAMILY, 0, &family) ==
            FcResultMatch) {
            [ret addObject: [NSString stringWithUTF8String: (const char *)
                                                                    family]];
        }
    }

    FcPatternDestroy(pat);
    FcObjectSetDestroy(props);
    FcFontSetDestroy(set);
    return ret;
}

- (NSString *) substituteFamilyName: (NSString *) familyName {
    FcConfig *config = O2FontSharedFontConfig();

    FcPattern *pat = FcNameParse((FcChar8 *) [familyName UTF8String]);
    FcConfigSubstitute(config, pat, FcMatchPattern);
    FcDefaultSubstitute(pat);

    FcResult fcResult;
    FcPattern *match = FcFontMatch(config, pat, &fcResult);
    FcPatternDestroy(pat);
    if (match == NULL)
        return NULL;

    FcChar8 *rawRes = NULL;
    FcPatternGetString(match, FC_FAMILY, 0, &rawRes);

    NSString *res = nil;
    if (rawRes != NULL) {
        res = [NSString stringWithUTF8String: (char *) rawRes];
    }

    FcPatternDestroy(match);
    return res;
}

- (NSArray<NSFontTypeface *> *) fontTypefacesForFamilyName:
        (NSString *) familyName
{
    familyName = [self substituteFamilyName: familyName];
    if (familyName == nil) {
        return @[];
    }
    FcPattern *pat = FcPatternCreate();
    FcPatternAddString(pat, FC_FAMILY,
                       (unsigned char *) [familyName UTF8String]);
    FcObjectSet *props = FcObjectSetBuild(FC_FAMILY, FC_STYLE, FC_SLANT,
                                          FC_WIDTH, FC_WEIGHT, NULL);

    FcFontSet *set = FcFontList(O2FontSharedFontConfig(), pat, props);
    NSMutableArray *ret = [NSMutableArray array];

    for (int i = 0; i < set->nfont; i++) {
        FcChar8 *typeface;
        FcPattern *p = set->fonts[i];
        if (FcPatternGetString(p, FC_STYLE, 0, &typeface) == FcResultMatch) {
            NSString *traitName =
                    [NSString stringWithUTF8String: (const char *) typeface];
            FcChar8 *pattern = FcNameUnparse(p);
            NSString *name =
                    [NSString stringWithUTF8String: (const char *) pattern];
            FcStrFree(pattern);

            NSFontTraitMask traits = 0;
            int slant, width, weight;
            FcPatternGetInteger(p, FC_SLANT, FC_SLANT_ROMAN, &slant);
            FcPatternGetInteger(p, FC_WIDTH, FC_WIDTH_NORMAL, &width);
            FcPatternGetInteger(p, FC_WEIGHT, FC_WEIGHT_REGULAR, &weight);

            switch (slant) {
            case FC_SLANT_OBLIQUE:
            case FC_SLANT_ITALIC:
                traits |= NSItalicFontMask;
                break;
            default:
                traits |= NSUnitalicFontMask;
                break;
            }

            if (weight <= FC_WEIGHT_LIGHT)
                traits |= NSUnboldFontMask;
            else if (weight >= FC_WEIGHT_SEMIBOLD)
                traits |= NSBoldFontMask;

            if (width <= FC_WIDTH_SEMICONDENSED)
                traits |= NSNarrowFontMask;
            else if (width >= FC_WIDTH_SEMIEXPANDED)
                traits |= NSExpandedFontMask;

            NSFontTypeface *face =
                    [[NSFontTypeface alloc] initWithName: name
                                               traitName: traitName
                                                  traits: traits];
            [ret addObject: face];
            [face release];
        }
    }

    FcPatternDestroy(pat);
    FcObjectSetDestroy(props);
    FcFontSetDestroy(set);
    return ret;
}

- (CGFloat) scrollerWidth {
    return 15.0;
}

- (CGFloat) doubleClickInterval {
    return 1.0;
}

- (int) runModalPageLayoutWithPrintInfo: (NSPrintInfo *) printInfo {
    NSUnimplementedMethod();
    return 0;
}

- (int) runModalPrintPanelWithPrintInfoDictionary:
        (NSMutableDictionary *) attributes
{
    NSUnimplementedMethod();
    return 0;
}

- (O2Context *) graphicsPortForPrintOperationWithView: (NSView *) view
                                            printInfo: (NSPrintInfo *) printInfo
                                            pageRange: (NSRange) pageRange
{
    NSUnimplementedMethod();
    return nil;
}

- (int) savePanel: (NSSavePanel *) savePanel
        runModalForDirectory: (NSString *) directory
                        file: (NSString *) file
{
    NSUnimplementedMethod();
    return 0;
}

- (int) openPanel: (NSOpenPanel *) openPanel
        runModalForDirectory: (NSString *) directory
                        file: (NSString *) file
                       types: (NSArray *) types
{
    NSUnimplementedMethod();
    return 0;
}

- (NSPoint) mouseLocation {
    rclolQueryPointer(_display);
    int height = DisplayHeight(_display, DefaultScreen(_display));
    return NSMakePoint(rclolRootX, height - rclolRootY);
}

- (void) setWindow: (id) window forID: (XID) i {
    if (window)
        [_windowsByID
                setObject: window
                   forKey: [NSNumber
                                   numberWithUnsignedLong: (unsigned long) i]];
    else {
        [_windowsByID removeObjectForKey: [NSNumber numberWithUnsignedLong:
                                                            (unsigned long) i]];

        // if "lastFocusedWindow" is dying, drop it
        //
        // this is an ugly hack because we miss FocusOut events sometimes and
        // retaining the window causes it to keep popping back up endlessly even after dismissing it
        if (lastFocusedWindow && [[lastFocusedWindow platformWindow] windowHandle] == i)
            lastFocusedWindow = nil;
    }
}

- (id) windowForID: (XID) i {
    return [_windowsByID objectForKey: [NSNumber numberWithUnsignedLong: i]];
}

- (NSEvent *) nextEventMatchingMask: (NSEventMask) mask
                          untilDate: (NSDate *) untilDate
                             inMode: (NSRunLoopMode) mode
                            dequeue: (BOOL) dequeue
{
#ifndef DARLING
    [[NSRunLoop currentRunLoop] addInputSource: _inputSource forMode: mode];

    NSEvent *result = [super nextEventMatchingMask: mask
                                         untilDate: untilDate
                                            inMode: mode
                                           dequeue: dequeue];

    [[NSRunLoop currentRunLoop] removeInputSource: _inputSource forMode: mode];

    return result;
#else
    // Darling: the CFSocket runloop source watching the X connection is not
    // guaranteed to wake us, so a single blocking wait can sleep through
    // input forever (X events queue unread, app looks frozen). Poll with a
    // short slice instead. (darling-lol M2b)
    /* A past deadline means poll, not skip queued input. Chromium's event
     * pump regularly uses distantPast while checking for pending events. */
    [self processPendingEvents];
    NSEvent *result = [super nextEventMatchingMask:mask untilDate:[NSDate date]
                                           inMode:mode dequeue:dequeue];
    if (result != nil && [result type] == NSAppKitSystem)
        result = nil;
    NSTimeInterval remaining;
    while (result == nil && (remaining = [untilDate timeIntervalSinceNow]) > 0) {
        /* Display-link and input sources have no CF timer deadline. A 20ms
         * fallback can sleep past every 60Hz source wakeup; bound its latency
         * below a refresh interval while the socket wakeup path is polled. */
        NSTimeInterval slice = remaining < 0.004 ? remaining : 0.004;
        /* A quiet X connection must not prevent main-queue callbacks or
         * CF timers from running while AppKit waits for its next event. */
        CFStringRef cfMode = (mode == nil || [mode isEqual:NSDefaultRunLoopMode])
                ? kCFRunLoopDefaultMode : (CFStringRef)mode;
        SInt32 runResult = CFRunLoopRunInMode(cfMode, 0.0, true);
        extern void _dispatch_main_queue_callback_4CF(void *);
        _dispatch_main_queue_callback_4CF(NULL);
        [self processPendingEvents];
        /* Do not let NSRunLoop perform the timed wait here. Darling's
         * socket-backed Mach receive can ignore the CF timer deadline and
         * sleep forever, preventing Electron readiness promises, dispatch
         * work, and repeating timers from being serviced. Poll the nested
         * run loop without blocking, then bound the idle wait ourselves. */
        result = [super nextEventMatchingMask: mask
                                    untilDate: [NSDate date]
                                       inMode: mode
                                      dequeue: dequeue];
        if (result != nil && [result type] == NSAppKitSystem) {
            result = nil;
        }
        /* A handled source can immediately queue more work (Chromium and
         * libuv do this). Drain it before the idle poll delay; sleeping after
         * every callback caps a busy source at 50 callbacks per second. */
        if (result == nil && runResult == kCFRunLoopRunHandledSource)
            continue;
        if (result == nil) {
            /* Polling must honor timers in both the Cocoa mode and the CF
             * main-queue mode. A fixed 20ms sleep misses 60Hz deadlines. */
            CFRunLoopRef loop = CFRunLoopGetCurrent();
            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
            CFAbsoluteTime next = CFRunLoopGetNextTimerFireDate(loop, cfMode);
            if (mode && !CFEqual((CFStringRef)mode, cfMode)) {
                CFAbsoluteTime cocoaNext = CFRunLoopGetNextTimerFireDate(loop, (CFStringRef)mode);
                if (cocoaNext > 0 && (next <= 0 || cocoaNext < next)) next = cocoaNext;
            }
            if (next > 0 && next - now < slice)
                slice = next > now ? next - now : 0;
        }
        if (result == nil && slice > 0) {
            /* Keep this polling deadline independent of Mach wait timers. */
            struct { long seconds, nanoseconds; } delay = {
                0, (long)(slice * 1000000000.0)
            };
            extern long __lolsys_syscall(long, long, long, long, long, long, int);
            __lolsys_syscall((long)&delay, 0, 0, 0, 0, 0, 35 /* Linux nanosleep */);
        }
    }
    return result;
#endif
}

- (NSEventModifierFlags) modifierFlagsForState: (unsigned int) state {
    NSEventModifierFlags ret = 0;
    if (state & ShiftMask)
        ret |= NSShiftKeyMask;
    if (state & ControlMask)
        ret |= NSControlKeyMask;
    // if (state & Mod2Mask) // Mod2Mask is numlock
    //   ret |= NSCommandKeyMask;
    if (state & LockMask)
        ret |= NSAlphaShiftKeyMask;
    if (state & Mod4Mask)
        ret |= NSCommandKeyMask;
    if (state & Mod1Mask)
        ret |= NSAlternateKeyMask;
    if (state & Mod5Mask) // AltGr
        ret |= NSFunctionKeyMask;

    return ret;
}

- (NSArray *) orderedWindowNumbers {
    NSMutableArray *result = [NSMutableArray array];

    for (NSWindow *win in [NSApp windows]) {
        [result addObject: @([win windowNumber])];
    }

    NSUnimplementedFunction(); // (Window numbers not even remotely ordered)

    return result;
}

/* X key events carry the state BEFORE the transition. Cocoa flagsChanged
 * carries the state AFTER it. Keep both sides separately so releasing one
 * Shift/Command key does not clear the other, and reconcile missed releases
 * when the compositor intercepts a shortcut or changes keyboard focus. */
static unsigned int rclolModifierMask(unsigned int key) {
    switch (key) {
    case 50: case 62: return ShiftMask;
    case 37: case 105: return ControlMask;
    case 64: return Mod1Mask;
    case 108: return Mod5Mask;
    case 133: case 134: return Mod4Mask;
    default: return 0;
    }
}

- (void) postModifierKey:(unsigned int)key state:(unsigned int)state window:(id)delegate {
    NSEvent *event = [NSEvent keyEventWithType:NSFlagsChanged
        location:NSZeroPoint modifierFlags:[self modifierFlagsForState:state]
        timestamp:0 windowNumber:[delegate windowNumber] context:nil
        characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO
        keyCode:x11ToCarbon[key]];
    [self postEvent:event atStart:NO];
}

- (void) reconcileModifierKeys:(const char *)keys window:(id)delegate {
    unsigned int state = 0;
    for (unsigned int key = 0; key < 256; ++key)
        if (_modifierKeysDown[key]) state |= rclolModifierMask(key);
    for (unsigned int key = 0; key < 256; ++key) {
        unsigned int mask = rclolModifierMask(key);
        if (!mask) continue;
        BOOL down = keys && (keys[key / 8] & (1 << (key % 8)));
        if (down == _modifierKeysDown[key]) continue;
        _modifierKeysDown[key] = down;
        state &= ~mask;
        for (unsigned int other = 0; other < 256; ++other)
            if (_modifierKeysDown[other]) state |= rclolModifierMask(other);
        [self postModifierKey:key state:state window:delegate];
    }
}

- (void) postXEvent: (XEvent *) ev {
    id event = nil;
    NSEventType type;
    X11Window* window = (X11Window*) [self windowForID: ev->xany.window];

    id delegate = [window delegate];
    static int inputTrace = -1;
    if (inputTrace < 0) inputTrace = getenv("RCLOL_INPUT_TRACE") != NULL;
    if (inputTrace && (ev->type == KeyPress || ev->type == KeyRelease || ev->type == ButtonPress))
        NSLog(@"LOLINPUT X type=%d window=%lu mapped=%@ number=%ld", ev->type,
            (unsigned long)ev->xany.window, [delegate class], (long)[delegate windowNumber]);

    switch (ev->type) {
    case MotionNotify:
        rclolRootX = ev->xmotion.x_root;
        rclolRootY = ev->xmotion.y_root;
        rclolPointerState = ev->xmotion.state;
        rclolPointerStamp = mach_absolute_time();
        break;
    case KeyPress: case KeyRelease: case ButtonPress: case ButtonRelease:
    case EnterNotify: case LeaveNotify: case FocusIn: case FocusOut: case KeymapNotify:
        rclolPointerStamp = rclolModsStamp = 0;
        break;
    default:
        break;
    }

    switch (ev->type) {
    case KeyPress:
    case KeyRelease:;

        unsigned int key = ev->xkey.keycode;
        unsigned int mask = rclolModifierMask(key);
        if (mask || key == 66) {
            unsigned int state = ev->xkey.state;
            if (key == 66) {
                if (ev->type == KeyPress) state ^= LockMask;
            } else {
                _modifierKeysDown[key] = ev->type == KeyPress;
                state &= ~mask;
                for (unsigned int other = 0; other < 256; ++other)
                    if (_modifierKeysDown[other]) state |= rclolModifierMask(other);
            }
            [self postModifierKey:key state:state window:delegate];
            break;
        }
        NSEventModifierFlags modifierFlags = [self modifierFlagsForState: ev->xkey.state];
        char buf[20] = {0};
        KeySym keySym;
        int strLen;

        if (XFilterEvent(ev, None)) // XIM processing
            break;

        if (ev->type == KeyPress) {
            strLen = Xutf8LookupString(window->_xic, (XKeyPressedEvent *) ev, buf, sizeof(buf) - 1, &keySym, NULL);
            buf[strLen] = 0;
        } else {
            // Xutf8LookupString() may not be used with KeyRelease
            strLen = XLookupString((XKeyEvent*) ev, buf, sizeof(buf) - 1, &keySym, NULL);
            buf[strLen] = 0;
        }

        /* Host clipboard shortcuts use Control; the guest app expects Command.
         * Preserve other Control bindings, AltGr and explicit Super shortcuts. */
        if ((modifierFlags & NSControlKeyMask) &&
            !(modifierFlags & (NSCommandKeyMask | NSAlternateKeyMask)) &&
            (keySym == XK_v || keySym == XK_V || keySym == XK_c ||
             keySym == XK_C || keySym == XK_x || keySym == XK_X)) {
            modifierFlags = (modifierFlags & ~NSControlKeyMask) | NSCommandKeyMask;
            buf[0] = (char) ((keySym >= XK_A && keySym <= XK_Z) ?
                            keySym - XK_A + 'a' : keySym);
            buf[1] = 0;
        }

        id str = [[NSString alloc] initWithCString: buf
                                          encoding: NSUTF8StringEncoding];
        NSPoint pos =
                [window transformPoint: NSMakePoint(ev->xkey.x, ev->xkey.y)];

        uint16_t ucsCode = (uint16_t) X11KeySymToUCS(keySym); // All defined codes in the table fit into 16 bits
        NSString* strIg = [NSString stringWithCharacters: &ucsCode length: 1];

        // If there's an app that uses constants from HIToolbox/Events.h (e.g.
        // kVK_ANSI_A), this gives it a chance to work.
        const int carbonKeyCode = x11ToCarbon[ev->xkey.keycode];

        BOOL isARepeat = NO;

        if (ev->type == KeyPress) {
            isARepeat = _lastKeySym == keySym;
            _lastKeySym = keySym;
        } else {
            _lastKeySym = 0;
        }

        id event = [NSEvent keyEventWithType: ev->type == KeyPress ? NSKeyDown
                                                                   : NSKeyUp
                                    location: pos
                               modifierFlags: modifierFlags
                                   timestamp: 0.0
                                windowNumber: [delegate windowNumber]
                                     context: nil
                                  characters: str
                 charactersIgnoringModifiers: strIg
                                   isARepeat: isARepeat
                                     keyCode: carbonKeyCode];

        [self postEvent: event atStart: NO];

        [str release];
        break;

    case ButtonPress:;
        if (ev->xbutton.button >= Button4 && ev->xbutton.button <= 7) {
            pos = [window transformPoint:NSMakePoint(ev->xbutton.x, ev->xbutton.y)];
            CGFloat wheelX = ev->xbutton.button == 6 ? 1.0 :
                ev->xbutton.button == 7 ? -1.0 : 0.0;
            CGFloat wheelY = ev->xbutton.button == Button4 ? 1.0 :
                ev->xbutton.button == Button5 ? -1.0 : 0.0;
            static int scrollLines;
            if (!scrollLines) {
                const char *setting = getenv("RCLOL_SCROLL_SPEED");
                int requested = setting ? atoi(setting) : 3;
                scrollLines = requested >= 1 && requested <= 20 ? requested : 3;
            }
            wheelX *= scrollLines; wheelY *= scrollLines;
            event = [NSEvent mouseEventWithType:NSScrollWheel location:pos
                modifierFlags:[self modifierFlagsForState:ev->xbutton.state]
                window:delegate clickCount:0 deltaX:wheelX deltaY:wheelY];
            [self postEvent:event atStart:NO];
            break;
        }
        if (ev->xbutton.button == Button2 || ev->xbutton.button >= 8) {
            unsigned b = ev->xbutton.button == Button2 ? 2 : ev->xbutton.button - 5;
            if (b < 32) _otherButtonsDown |= 1u << b;
        }
        NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];

        if (now - lastClickTimeStamp < [self doubleClickInterval]) {
            clickCount++;
        } else {
            clickCount = 1;
        }
        lastClickTimeStamp = now;

        pos = [window
                transformPoint: NSMakePoint(ev->xbutton.x, ev->xbutton.y)];

        switch (ev->xbutton.button) {
        case Button1:
            type = NSLeftMouseDown;
            break;
        case Button3:
            type = NSRightMouseDown;
            break;
        default:
            type = NSOtherMouseDown;
        }

        event = [NSEvent
                mouseEventWithType: type
                          location: pos
                     modifierFlags: [self modifierFlagsForState: ev->xbutton
                                                                         .state]
                            window: delegate
                        clickCount: clickCount
                            deltaX: 0.0
                            deltaY: 0.0];
        [(NSEvent_mouse *) event _setButtonNumber:
            ev->xbutton.button == Button1 ? 0 : ev->xbutton.button == Button3 ? 1 :
            ev->xbutton.button == Button2 ? 2 : ev->xbutton.button - 5];
        [self postEvent: event atStart: NO];
        break;

    case ButtonRelease:
        // One scroll event per notch, sent on press; releases are not clicks.
        if (ev->xbutton.button >= Button4 && ev->xbutton.button <= 7) break;
        pos = [window
                transformPoint: NSMakePoint(ev->xbutton.x, ev->xbutton.y)];

        if (ev->xbutton.button == Button2 || ev->xbutton.button >= 8) {
            unsigned b = ev->xbutton.button == Button2 ? 2 : ev->xbutton.button - 5;
            if (b < 32) _otherButtonsDown &= ~(1u << b);
        }
        CGFloat deltaY = 0.0;

        switch (ev->xbutton.button) {
        case Button1:
            type = NSLeftMouseUp;
            break;
        case Button3:
            type = NSRightMouseUp;
            break;
        default:
            type = NSOtherMouseUp;
        }

        event = [NSEvent
                mouseEventWithType: type
                          location: pos
                     modifierFlags: [self modifierFlagsForState: ev->xbutton
                                                                         .state]
                            window: delegate
                        clickCount: clickCount
                            deltaX: 0.0
                            deltaY: deltaY];
        [event _setButtonNumber:
            ev->xbutton.button == Button1 ? 0 : ev->xbutton.button == Button3 ? 1 :
            ev->xbutton.button == Button2 ? 2 : ev->xbutton.button - 5];
        [self postEvent: event atStart: NO];
        break;

    case MotionNotify:; {
            // NSLog(@"MotionNotify, x=%d, y=%d, xroot=%d, yroot=%d\n",
            // ev->xmotion.x, ev->xmotion.y, ev->xmotion.x_root,
            // ev->xmotion.y_root);

            CGPoint lastMotionPos = [window mouseLocationOutsideOfEventStream];
            pos = [window
                    transformPoint: NSMakePoint(ev->xmotion.x, ev->xmotion.y)];

            CGFloat deltaX = pos.x - lastMotionPos.x;
            CGFloat deltaY = pos.y - lastMotionPos.y;

            // NSLog(@"cursorGrabbed=%d, deltaX=%f, deltaY=%f\n",
            // _cursorGrabbed, deltaX, deltaY);
            if (_cursorGrabbed) {
                if (pos.x != lastMotionPos.x || pos.y != lastMotionPos.y) {
                    CGPoint globalPos = [window transformPoint: lastMotionPos];
                    // NSLog(@"last known pos in window: x=%f, y=%f",
                    // globalPos.x, globalPos.y);
                    CGRect frame = [window transformFrame: [window frame]];

                    globalPos.x += frame.origin.x;
                    globalPos.y += frame.origin.y;

                    [self warpMouse: globalPos];

                    pos.x = lastMotionPos.x;
                    pos.y = lastMotionPos.y;
                } else {
                    // This is an event generated by [self warpMouse:] above
                    break;
                }
            } else {
                [window setLastKnownCursorPosition: pos];
            }

            type = NSMouseMoved;

            [self pointerMoved];
            if (ev->xmotion.state & Button1Mask) {
                type = NSLeftMouseDragged;
            } else if (ev->xmotion.state & Button3Mask) {
                type = NSRightMouseDragged;
            } else if ((ev->xmotion.state & Button2Mask) || _otherButtonsDown) {
                type = NSOtherMouseDragged;
            }

            if (inputTrace) {
                static NSTimeInterval lastMotionTrace;
                NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
                if (now - lastMotionTrace >= 1.0) {
                    lastMotionTrace = now;
                    NSLog(@"LOLINPUT motion window=%lu mapped=%@ pos=%.0f,%.0f delta=%.0f,%.0f state=%u grabbed=%d forward=%d",
                        (unsigned long)ev->xany.window, [delegate class],
                        pos.x, pos.y, deltaX, deltaY, ev->xmotion.state,
                        _cursorGrabbed, type != NSMouseMoved || [delegate acceptsMouseMovedEvents] ||
                        getenv("RCLOL_FORWARD_MOUSE_MOVED") != NULL);
                }
            }

            if (type != NSMouseMoved || [delegate acceptsMouseMovedEvents] ||
                getenv("RCLOL_FORWARD_MOUSE_MOVED")) {
              event = [NSEvent
                    mouseEventWithType: type
                              location: pos
                         modifierFlags:
                                 [self modifierFlagsForState: ev->xmotion.state]
                                window: delegate
                            clickCount: 1
                                deltaX: deltaX
                                deltaY: deltaY];
            if (type == NSOtherMouseDragged) {
                unsigned buttons = _otherButtonsDown | ((ev->xmotion.state & Button2Mask) ? 4u : 0u);
                [event _setButtonNumber: __builtin_ctz(buttons)];
            }
            [self postEvent: event atStart: NO];
            [self discardEventsMatchingMask: NSEventMaskFromType(type)
                                beforeEvent: event];
            }

            /* Tracking areas need motion even when the window doesn't ask
             * for general mouseMoved events (Chromium uses this mode). */
            [delegate platformWindowSetCursorEvent: window];
            break;
        }

    case EnterNotify:
        [self updateMouseConfinementForWindow:window];
        NSLog(@"EnterNotify");
        if (!_cursorGrabbed)
            [window setLastKnownCursorPosition:
                            [window transformPoint: NSMakePoint(
                                                            ev->xcrossing.x,
                                                            ev->xcrossing.y)]];
        if (!_cursorGrabbed && ev->xcrossing.detail != NotifyInferior)
            [delegate platformWindowSetCursorEvent: window];
        break;

    case LeaveNotify:
        NSLog(@"LeaveNotify");
        if (!_cursorGrabbed && ev->xcrossing.detail != NotifyInferior) {
            [window setLastKnownCursorPosition:
                [window transformPoint: NSMakePoint(ev->xcrossing.x, ev->xcrossing.y)]];
            [delegate platformWindowSetCursorEvent: window];
        }
        break;

    case FocusIn:
        NSLog(@"FocusIn");
        if ([delegate attachedSheet]) {
            [[delegate attachedSheet] makeKeyAndOrderFront: delegate];
            break;
        }
        if (lastFocusedWindow) {
            [lastFocusedWindow platformWindowDeactivated: window
                                 checkForAppDeactivation: NO];
            lastFocusedWindow = nil;
        }
        char modifierKeys[32];
        XQueryKeymap(_display, modifierKeys);
        [self reconcileModifierKeys:modifierKeys window:delegate];
        [delegate platformWindowActivated: window displayIfNeeded: YES];
        lastFocusedWindow = delegate;
        if (window != nil)
            XSetICFocus(window->_xic);
        [self updateMouseConfinementForWindow:window];
        break;

    case FocusOut:
        NSLog(@"FocusOut");
        [self reconcileModifierKeys:NULL window:delegate];
        _lastKeySym = 0;
        [delegate platformWindowDeactivated: window
                    checkForAppDeactivation: NO];
        lastFocusedWindow = nil;
        if (_cursorGrabbed)
            [self grabMouse: NO];
        if (_confinedWindow) {
            XUngrabPointer(_display, CurrentTime);
            _confinedWindow = None;
        }
        _otherButtonsDown = 0;
        if (window != nil)
            XUnsetICFocus(window->_xic);
        break;

    case KeymapNotify:
        NSLog(@"KeymapNotify");
        [self reconcileModifierKeys:ev->xkeymap.key_vector window:lastFocusedWindow];
        break;

    case Expose:;
        if ([window handleRemoteFrameExpose: ev->xany.window])
            break;
        O2Rect rect = NSMakeRect(ev->xexpose.x, ev->xexpose.y,
                                 ev->xexpose.width, ev->xexpose.height);

        rect.origin.y =
                [window frame].size.height - rect.origin.y - rect.size.height;
        // rect=NSInsetRect(rect, -10, -10);
        // [_backingContext addToDirtyRect:rect];
        if (ev->xexpose.count == 0)
            [window flushBuffer];

        [delegate platformWindowExposed: window inRect: rect];
        break;

    case GraphicsExpose:
        NSLog(@"GraphicsExpose");
        break;

    case NoExpose:
        NSLog(@"NoExpose");
        break;

    case VisibilityNotify:
        NSLog(@"VisibilityNotify");
        break;

    case CreateNotify:
        NSLog(@"CreateNotify");
        break;

    case DestroyNotify:;
        // we should never get this message before the WM_DELETE_WINDOW
        // ClientNotify so normally, window should be nil here.
        [window invalidate];
        break;

    case UnmapNotify:
    case MapNotify:
        /* Map state belongs to the top-level native window. Remote frame and
         * GL children must not change its Cocoa visibility or occlusion state. */
        if(window && ev->xany.window == [window windowHandle] &&
           [delegate respondsToSelector: @selector(_setVisible:)]) {
            BOOL visible = ev->type == MapNotify;
            [self updateMouseConfinementForWindow:window];
            if([delegate isVisible] != visible) {
                [delegate _setVisible: visible];
                [[NSNotificationCenter defaultCenter]
                    postNotificationName: NSWindowDidChangeOcclusionStateNotification
                    object: delegate];
            }
        }
        break;

    case MapRequest:
        NSLog(@"MapRequest");
        break;

    case ReparentNotify:
        NSLog(@"ReparentNotify");
        break;

    case ConfigureNotify:
        [window frameChanged];
        [delegate platformWindow: window
                    frameChanged: [window frame]
                         didSize: YES];
        [self updateMouseConfinementForWindow:window];
        break;

    case ConfigureRequest:
        NSLog(@"ConfigureRequest");
        break;

    case GravityNotify:
        NSLog(@"GravityNotify");
        break;

    case ResizeRequest:
        NSLog(@"ResizeRequest");
        break;

    case CirculateNotify:
        NSLog(@"CirculateNotify");
        break;

    case CirculateRequest:
        NSLog(@"CirculateRequest");
        break;

    case PropertyNotify:
        if (ev->xproperty.atom == XInternAtom(_display, "_NET_WM_STATE", False))
            [self updateMouseConfinementForWindow:window];
        if ([window respondsToSelector: @selector(propertyNotify:)]) {
            [window propertyNotify: &ev->xproperty];
        }
        break;

    case SelectionClear:
        if ([window respondsToSelector: @selector(selectionClear:)]) {
            [window selectionClear: &ev->xselectionclear];
        }
        break;

    case SelectionRequest:
        if ([window respondsToSelector: @selector(selectionRequest:)]) {
            [window selectionRequest: &ev->xselectionrequest];
        }
        break;

    case SelectionNotify:
        if ([window respondsToSelector: @selector(selectionNotify:)]) {
            [window selectionNotify: &ev->xselection];
        }
        break;

    case ColormapNotify:
        NSLog(@"ColormapNotify");
        break;

    case ClientMessage:
        if (ev->xclient.format == 32 &&
            ev->xclient.data.l[0] ==
                    XInternAtom(_display, "WM_DELETE_WINDOW", False)) {
            NSLog(@"ClientMessage:WM_DELETE_WINDOW");
            [[NSRunLoop currentRunLoop] cancelPerformSelector: @selector(platformWindowWillClose:)
                                                       target: delegate
                                                     argument: window];
            [[NSRunLoop currentRunLoop] performSelector: @selector(platformWindowWillClose:)
                                                 target: delegate
                                               argument: window
                                                  order: 0
                                                  modes: @[
                                                        NSDefaultRunLoopMode, NSModalPanelRunLoopMode,
                                                        NSEventTrackingRunLoopMode
                                                    ]];
        }
        break;

    case MappingNotify:
        NSLog(@"MappingNotify");
        break;

    case GenericEvent:
        NSLog(@"GenericEvent");
        break;

    default:
        if (ev->type == _rrEventBase + RRNotify) {
            [self _invalidateRRCache];
            break;
        }
        NSLog(@"Unknown X11 event type %i", ev->type);
        break;
    }
}

#ifndef DARLING
- (void) selectInputSource: (NSSelectInputSource *) inputSource
               selectEvent: (NSUInteger) selectEvent
{
#else
- (void) processPendingEvents {
#endif
    int numEvents;

    while ((numEvents = XPending(_display)) > 0) {
        XEvent e;
        int error;

        if ((error = XNextEvent(_display, &e)) != 0)
            NSLog(@"XNextEvent returned %d", error);
        else
            [self postXEvent: &e];
    }
}

- (int) handleError: (XErrorEvent *) errorEvent {
    NSLog(@"************** X11 ERROR!");
    NSLog(@"Request code: %d:%d", errorEvent->request_code,
          errorEvent->minor_code);
    NSLog(@"Error code: %d", errorEvent->error_code);
    return 0;
}

void CGNativeBorderFrameWidthsForStyle(NSUInteger styleMask, CGFloat *top,
                                       CGFloat *left, CGFloat *bottom,
                                       CGFloat *right)
{
    *top = 0.0;
    *left = 0.0;
    *bottom = 0.0;
    *right = 0.0;
}

- (CGRect) insetRect: (CGRect) frame
        forNativeWindowBorderWithStyle: (NSUInteger) styleMask
{
    CGFloat top, left, bottom, right;

    CGNativeBorderFrameWidthsForStyle(styleMask, &top, &left, &bottom, &right);

    frame.origin.x += left;
    frame.origin.y += bottom;
    frame.size.width -= left + right;
    frame.size.height -= top + bottom;

    return frame;
}

- (CGRect) outsetRect: (CGRect) frame
        forNativeWindowBorderWithStyle: (NSUInteger) styleMask
{
    CGFloat top, left, bottom, right;

    CGNativeBorderFrameWidthsForStyle(styleMask, &top, &left, &bottom, &right);

    frame.origin.x -= left;
    frame.origin.y -= bottom;
    frame.size.width += left + right;
    frame.size.height += top + bottom;

    return frame;
}

- (void) warpMouse: (NSPoint) position {
    NSLog(@"Warp to: x=%f, y=%f\n", position.x, position.y);
    XWarpPointer(_display, None, DefaultRootWindow(_display), 0, 0, 0, 0,
                 position.x, position.y);
    XSync(_display, False);
}

/* Confinement preserves absolute motion and edge panning. Relative-mode
 * capture remains separate: it deliberately warps to the center. */
- (void) updateMouseConfinementForWindow:(X11Window *)window {
    if (getenv("RCLOL_INPUT_TRACE")) fprintf(stderr,"CONFINEMENT check window=%p delegate=%p focused=%p relative=%d\n",window,[window delegate],lastFocusedWindow,_cursorGrabbed);
    if (!window || _cursorGrabbed) return;
    Window win = [window windowHandle];
    Window focus; int revert;
    XGetInputFocus(_display, &focus, &revert);
    Window ancestor = focus;
    while (ancestor != win && ancestor != None && ancestor != PointerRoot && ancestor != DefaultRootWindow(_display)) {
        Window root, parent, *children=NULL; unsigned nchildren;
        if (!XQueryTree(_display, ancestor, &root, &parent, &children, &nchildren)) break;
        if (children) XFree(children);
        ancestor=parent;
    }
    if (getenv("RCLOL_INPUT_TRACE")) fprintf(stderr,"CONFINEMENT focus=%lu target=%lu ancestor=%lu\n",focus,win,ancestor);
    if (ancestor != win) return;
    XWindowAttributes attrs;
    if (!XGetWindowAttributes(_display, win, &attrs)) return;
    BOOL fullscreen = NO;
    Atom actual; int format; unsigned long count, remaining; unsigned char *data = NULL;
    Atom state = XInternAtom(_display, "_NET_WM_STATE", False);
    Atom fs = XInternAtom(_display, "_NET_WM_STATE_FULLSCREEN", False);
    if (XGetWindowProperty(_display, win, state, 0, 64, False, XA_ATOM,
        &actual, &format, &count, &remaining, &data) == Success && format == 32) {
        for (unsigned long i=0; i<count; ++i) if (((Atom *)data)[i] == fs) fullscreen = YES;
    }
    if (data) XFree(data);
    /* League's borderless fullscreen does not set the EWMH fullscreen bit.
     * Recognize a borderless window covering one monitor, including monitor 2. */
    if (!fullscreen && !([[window delegate] styleMask] & NSTitledWindowMask)) {
        Window child; int x, y;
        XTranslateCoordinates(_display, win, DefaultRootWindow(_display), 0, 0, &x, &y, &child);
        XRRScreenResources *resources = XRRGetScreenResourcesCurrent(_display, DefaultRootWindow(_display));
        if (resources) {
            for (int i=0; i<resources->ncrtc; ++i) {
                XRRCrtcInfo *crtc = XRRGetCrtcInfo(_display, resources, resources->crtcs[i]);
                if (crtc) {
                    if (crtc->mode && abs(x-crtc->x)<=2 && abs(y-crtc->y)<=2 &&
                        abs(attrs.width-(int)crtc->width)<=2 && abs(attrs.height-(int)crtc->height)<=2) fullscreen=YES;
                    XRRFreeCrtcInfo(crtc);
                }
            }
            XRRFreeScreenResources(resources);
        }
    }
    if (!fullscreen || attrs.map_state != IsViewable) {
        if (_confinedWindow == win) { XUngrabPointer(_display, CurrentTime); _confinedWindow=None; }
        return;
    }
    if (_confinedWindow == win) return;
    unsigned mask = ButtonPressMask | ButtonReleaseMask | PointerMotionMask;
    int status=XGrabPointer(_display, win, True, mask, GrabModeAsync, GrabModeAsync,
        win, None, CurrentTime);
    if (getenv("RCLOL_INPUT_TRACE")) fprintf(stderr,"CONFINEMENT fullscreen=%d window=%lu result=%d\n",fullscreen,win,status);
    if (status == GrabSuccess) _confinedWindow=win;
}

- (void) grabMouse: (BOOL) doGrab {
    if (doGrab) {
        NSWindow *nswin = [NSApp keyWindow];
        if (!nswin)
            nswin = [NSApp mainWindow];

        X11Window *xwin = (X11Window *) [nswin platformWindow];
        Window win = [xwin windowHandle];
        // Window win = DefaultRootWindow(_display);
        const unsigned int mask = ButtonPressMask | ButtonReleaseMask |
                                  PointerMotionMask | FocusChangeMask;
        int result = XGrabPointer(_display, win, False, mask, GrabModeAsync,
                                  GrabModeAsync, win, None, CurrentTime);
        if (result == GrabSuccess) {
            _cursorGrabbed = YES;
            _confinedWindow = None;
            NSLog(@"XGrabPointer() succeeded for window %lu\n", win);

            NSRect frame = [xwin transformFrame: nswin.frame];
            // NSLog(@"Window's frame is at %f,%f, size %fx%f\n",
            // frame.origin.x, frame.origin.y, frame.size.width,
            // frame.size.height);
            CGPoint ptGlobal =
                    NSMakePoint(frame.size.width / 2.0 + frame.origin.x,
                                frame.size.height / 2.0 + frame.origin.y);
            CGPoint ptLocal = NSMakePoint(frame.size.width / 2.0,
                                          frame.size.height / 2.0);

            // NSLog(@"setting last known pos in window to x=%f, y=%f\n",
            // ptLocal.x, ptLocal.y);

            [xwin setLastKnownCursorPosition: [xwin transformPoint: ptLocal]];
            [self warpMouse: ptGlobal];
        } else {
            NSLog(@"XGrabPointer() failed with error %d for window %lu\n",
                  result, win);
        }
    } else {
        XUngrabPointer(_display, CurrentTime);
        _cursorGrabbed = NO;
        _confinedWindow = None;
        NSWindow *nswin = [NSApp keyWindow];
        if (nswin) [self updateMouseConfinementForWindow:(X11Window *)[nswin platformWindow]];
    }
    XSync(_display, False);
}

@end

#import <AppKit/NSGraphicsStyle.h>

@implementation NSGraphicsStyle (Overrides)
- (void) drawMenuBranchArrowInRect: (NSRect) rect selected: (BOOL) selected {
    NSImage *arrow = [NSImage imageNamed: @"NSMenuArrow"];
    // ??? magic numbers
    rect.origin.y += 5;
    rect.origin.x -= 2;
    [arrow drawInRect: rect
             fromRect: NSZeroRect
            operation: NSCompositeSourceOver
             fraction: 1.0];
}

@end
