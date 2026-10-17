/*
 This file is part of Darling.

 Copyright (C) 2020 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "CGDisplayGeometry.h"
#import <AppKit/NSDisplay.h>
#import <AppKit/NSScreen.h>
#import <CoreGraphics/CGDirectDisplay.h>
#import <CoreGraphics/CGColorSpace.h>
#import <CoreGraphics/CGError.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <IOKit/graphics/IOGraphicsTypes.h>
#include <dlfcn.h>
#import <CoreFoundation/CFUUID.h>


// not sure what type or value this has
unsigned int kCGDisplayPixelHeight = kCGDisplayHeight;
unsigned int kCGDisplayPixelWidth = kCGDisplayWidth;

const CFStringRef kCGDisplayProductNameKey = CFSTR("kCGDisplayProductNameKey");
const CFStringRef kCGDisplayShowDuplicateLowResolutionModes = CFSTR("kCGDisplayShowDuplicateLowResolutionModes");

CGError CGCaptureAllDisplays(void) {
    return kCGErrorSuccess;
}

CGError CGReleaseAllDisplays(void) {
    return kCGErrorSuccess;
}

// Our platform abstraction is in AppKit
static NSDisplay *currentDisplay(void) {
    Class appCls = NSClassFromString(@"NSApplication");
    if (!appCls)
        return nil;

    Class cls = NSClassFromString(@"NSDisplay");
    if (!cls)
        return nil;

    @try {
        return [cls currentDisplay];
    }
    @catch (id exception) {
        return nil;
    }
}


// A display's ID belongs to the screen (the backend ties it to the output it
// drives), and [NSScreen screens] lists the main screen first, so an array
// position is not an ID.
static NSScreen *screenForDisplayID(NSArray<NSScreen *> *screens,
                                    CGDirectDisplayID displayID)
{
    for (NSScreen *screen in screens) {
        if ([screen cgDirectDisplayID] == displayID)
            return screen;
    }
    return nil;
}

// NSScreen frames are in Cocoa's global space (origin at the main screen's
// bottom-left corner, y up, like window frames); CoreGraphics' global space has its
// origin at the main screen's top-left corner and y down, so a display above the main
// one has a negative y, as on macOS. [NSScreen screens] lists the main screen first.
static CGRect globalRectForFrame(NSArray<NSScreen *> *screens, NSRect frame) {
    if (NSIsEmptyRect(frame) || [screens count] == 0)
        return frame;
    CGFloat mainHeight = NSHeight([[screens objectAtIndex: 0] frame]);
    return CGRectMake(frame.origin.x,
                      mainHeight - frame.origin.y - frame.size.height,
                      frame.size.width, frame.size.height);
}

CGDirectDisplayID CGMainDisplayID(void) {
    NSDisplay *display = currentDisplay();
    if (!display)
        return 1;

    NSArray<NSScreen *> *screens = [display screens];
    if ([screens count] == 0)
        return 1;

    for (NSScreen *screen in screens) {
        if (!NSIsEmptyRect([screen frame])) {
            return [screen cgDirectDisplayID];
        }
    }

    return 1;
}

CGError CGGetOnlineDisplayList(uint32_t maxDisplays,
                               CGDirectDisplayID *onlineDisplays,
                               uint32_t *displayCount)
{
    NSDisplay *display = currentDisplay();
    if (!display || [[display screens] count] == 0) {
        *displayCount = 1;
        if (maxDisplays > 0 && onlineDisplays)
            onlineDisplays[0] = 1;
        return kCGErrorSuccess;
    }

    NSArray<NSScreen *> *screens = [display screens];
    const CGDirectDisplayID mainDisplay = CGMainDisplayID();

    *displayCount = 0;

    // Main display should be the first returned
    if (mainDisplay != kCGNullDirectDisplay) {
        (*displayCount)++;
        if (maxDisplays > 0 && onlineDisplays)
            onlineDisplays[0] = mainDisplay;
    }

    for (NSScreen *screen in screens) {
        CGDirectDisplayID displayID = [screen cgDirectDisplayID];
        if (displayID != mainDisplay) {
            if (*displayCount < maxDisplays && onlineDisplays)
                onlineDisplays[*displayCount] = displayID;
            (*displayCount)++;
        }
    }

    return kCGErrorSuccess;
}

size_t CGDisplayPixelsHigh(CGDirectDisplayID displayIndex) {
    NSDisplay *display = currentDisplay();
    if (!display || [[display screens] count] == 0)
        return (displayIndex == 1) ? 1080 : 0;

    NSScreen *screen = screenForDisplayID([display screens], displayIndex);
    if (!screen)
        return 0;

    // Device pixels, not points. NSScreen.frame is in points, and CGDisplayBounds
    // reports points, so returning the frame size here halved the value on a 2x
    // display and any caller sizing a bitmap from CGDisplayPixelsWide got half the
    // pixels it asked for.
    CGFloat scale = [screen backingScaleFactor];
    return (size_t) lround(NSHeight([screen frame]) * scale);
}

size_t CGDisplayPixelsWide(CGDirectDisplayID displayIndex) {
    NSDisplay *display = currentDisplay();
    if (!display || [[display screens] count] == 0)
        return (displayIndex == 1) ? 1920 : 0;

    NSScreen *screen = screenForDisplayID([display screens], displayIndex);
    if (!screen)
        return 0;

    // Device pixels, not points; see CGDisplayPixelsHigh.
    CGFloat scale = [screen backingScaleFactor];
    return (size_t) lround(NSWidth([screen frame]) * scale);
}

CGError CGGetActiveDisplayList(uint32_t maxDisplays,
                               CGDirectDisplayID *activeDisplays,
                               uint32_t *displayCount)
{
    NSDisplay *display = currentDisplay();
    if (!display || [[display screens] count] == 0) {
        *displayCount = 1;
        if (maxDisplays > 0 && activeDisplays)
            activeDisplays[0] = 1;
        return kCGErrorSuccess;
    }

    NSArray<NSScreen *> *screens = [display screens];

    *displayCount = 0;
    for (NSScreen *screen in screens) {
        if (!NSIsEmptyRect([screen frame])) {
            if (*displayCount < maxDisplays && activeDisplays)
                activeDisplays[*displayCount] = [screen cgDirectDisplayID];
            (*displayCount)++;
        }
    }

    return kCGErrorSuccess;
}

CGError CGGetDisplaysWithOpenGLDisplayMask(CGOpenGLDisplayMask mask,
                                           uint32_t maxDisplays,
                                           CGDirectDisplayID *displays,
                                           uint32_t *matchingDisplayCount)
{
    return CGGetOnlineDisplayList(maxDisplays, displays, matchingDisplayCount);
}

CGDirectDisplayID CGOpenGLDisplayMaskToDisplayID(CGOpenGLDisplayMask mask) {
    return CGMainDisplayID();
}

CGError CGGetDisplaysWithPoint(CGPoint point, uint32_t maxDisplays,
                               CGDirectDisplayID *displays,
                               uint32_t *matchingDisplayCount)
{
    NSDisplay *display = currentDisplay();
    if (!display)
        return kCGErrorInvalidConnection;

    NSArray<NSScreen *> *screens = [display screens];
    *matchingDisplayCount = 0;

    for (NSScreen *screen in screens) {
        NSRect rect = globalRectForFrame(screens, [screen frame]);
        if (NSPointInRect(point, rect)) {
            if (*matchingDisplayCount < maxDisplays)
                displays[*matchingDisplayCount] = [screen cgDirectDisplayID];
            (*matchingDisplayCount)++;
        }
    }

    return kCGErrorSuccess;
}

CGError CGGetDisplaysWithRect(CGRect rect, uint32_t maxDisplays,
                              CGDirectDisplayID *displays,
                              uint32_t *matchingDisplayCount)
{
    NSDisplay *display = currentDisplay();
    if (!display)
        return kCGErrorInvalidConnection;

    NSArray<NSScreen *> *screens = [display screens];
    *matchingDisplayCount = 0;

    for (NSScreen *screen in screens) {
        NSRect screenRect = globalRectForFrame(screens, [screen frame]);
        if (NSIntersectsRect(rect, screenRect)) {
            if (*matchingDisplayCount < maxDisplays)
                displays[*matchingDisplayCount] = [screen cgDirectDisplayID];
            (*matchingDisplayCount)++;
        }
    }

    return kCGErrorSuccess;
}

CGError CGDisplayCapture(CGDirectDisplayID display) {
    return kCGErrorSuccess;
}

CGError CGDisplayRelease(CGDirectDisplayID display) {
    return kCGErrorSuccess;
}

CGRect CGDisplayBounds(CGDirectDisplayID displayIndex) {
    NSDisplay *display = currentDisplay();
    if (!display || [[display screens] count] == 0) {
        if (displayIndex == 1)
            return CGRectMake(0, 0, 1920, 1080);
        return CGRectZero;
    }

    NSArray<NSScreen *> *screens = [display screens];
    NSScreen *screen = screenForDisplayID(screens, displayIndex);
    if (!screen)
        return CGRectZero;

    return globalRectForFrame(screens, [screen frame]);
}

CGError CGDisplayHideCursor(CGDirectDisplayID displayIndex) {
    NSDisplay *display = currentDisplay();
    if (!display)
        return kCGErrorInvalidConnection;

    [display hideCursor];
    return kCGErrorSuccess;
}

CGError CGDisplayShowCursor(CGDirectDisplayID displayIndex) {
    NSDisplay *display = currentDisplay();
    if (!display)
        return kCGErrorInvalidConnection;

    [display unhideCursor];
    return kCGErrorSuccess;
}

CFArrayRef CGDisplayAvailableModes(CGDirectDisplayID displayIndex) {
    NSDisplay *display = currentDisplay();
    if (!display)
        return NULL;
    return (CFArrayRef) [display modesForScreen: displayIndex - 1];
}

boolean_t CGDisplayIsInMirrorSet(CGDirectDisplayID display) {
    printf("STUB %s\n", __PRETTY_FUNCTION__);

    return FALSE;
}

Boolean CGDisplayIsMain(CGDirectDisplayID display) {
    return display != kCGNullDirectDisplay && display == CGMainDisplayID();
}

uint32_t CGDisplayUnitNumber(CGDirectDisplayID display) {
    return (display > 0) ? (display - 1) : 0;
}

boolean_t CGDisplayUsesOpenGLAcceleration(CGDirectDisplayID display) {
    return TRUE;
}

CGDirectDisplayID CGDisplayMirrorsDisplay(CGDirectDisplayID display) {
    return kCGNullDirectDisplay;
}

static NSDictionary *defaultDisplayMode(void) {
    static dispatch_once_t onceToken;
    static NSDictionary *cachedMode = nil;
    dispatch_once(&onceToken, ^{
        unsigned int width = 1920, height = 1080;
        const char *dispEnv = getenv("DISPLAY");
        if (dispEnv && dispEnv[0]) {
            void *x11 = dlopen("/usr/lib/native/libX11.so.6", RTLD_LAZY);
            if (!x11) x11 = dlopen("libX11.so.6", RTLD_LAZY);
            if (x11) {
                typedef void* (*XOpenDisplay_fn)(const char*);
                typedef int (*XDefaultScreen_fn)(void*);
                typedef int (*XDisplayWidth_fn)(void*, int);
                typedef int (*XDisplayHeight_fn)(void*, int);
                typedef int (*XCloseDisplay_fn)(void*);
                XOpenDisplay_fn xopen = (XOpenDisplay_fn)dlsym(x11, "XOpenDisplay");
                XDefaultScreen_fn xdef = (XDefaultScreen_fn)dlsym(x11, "XDefaultScreen");
                XDisplayWidth_fn xw = (XDisplayWidth_fn)dlsym(x11, "XDisplayWidth");
                XDisplayHeight_fn xh = (XDisplayHeight_fn)dlsym(x11, "XDisplayHeight");
                XCloseDisplay_fn xclose = (XCloseDisplay_fn)dlsym(x11, "XCloseDisplay");
                if (xopen && xdef && xw && xh && xclose) {
                    void *d = xopen(dispEnv);
                    if (d) {
                        int s = xdef(d);
                        width = xw(d, s);
                        height = xh(d, s);
                        xclose(d);
                    }
                }
                dlclose(x11);
            }
        }
        cachedMode = [@{
            @"Width": @(width),
            @"Height": @(height),
            @"PixelWidth": @(width),
            @"PixelHeight": @(height),
            @"Depth": @24,
            @"RefreshRate": @60.0,
            @"IOFlags": @(0x00000007),
            @"UsableForDesktopGUI": @YES
        } retain];
    });
    return cachedMode;
}

CGDisplayModeRef CGDisplayCopyDisplayMode(CGDirectDisplayID displayId) {
    NSDisplay *display = currentDisplay();
    NSDictionary *dict = nil;
    if (display) {
        dict = [display currentModeForScreen: displayId - 1];
    }
    if (!dict || [dict count] == 0) {
        dict = defaultDisplayMode();
    }
    return (CGDisplayModeRef) [dict retain];
}

void CGDisplayModeRelease(CGDisplayModeRef mode) {
    if (mode != NULL)
        CFRelease(mode);
}

CGDisplayModeRef CGDisplayModeRetain(CGDisplayModeRef mode) {
    if (mode)
        CFRetain(mode);
    return mode;
}

size_t CGDisplayModeGetHeight(CGDisplayModeRef mode) {
    NSDictionary *dict = (NSDictionary *) mode;
    return [[dict valueForKey: @"Height"] unsignedIntValue];
}

size_t CGDisplayModeGetWidth(CGDisplayModeRef mode) {
    NSDictionary *dict = (NSDictionary *) mode;
    return [[dict valueForKey: @"Width"] unsignedIntValue];
}

double CGDisplayModeGetRefreshRate(CGDisplayModeRef mode) {
    NSDictionary *dict = (NSDictionary *) mode;
    return [[dict valueForKey: @"RefreshRate"] doubleValue];
}

#ifndef IO32BitDirectPixels
#define IO32BitDirectPixels "--------RRRRRRRRGGGGGGGGBBBBBBBB"
#endif
#ifndef IO16BitDirectPixels
#define IO16BitDirectPixels "-RRRRRGGGGGBBBBB"
#endif

CFStringRef CGDisplayModeCopyPixelEncoding(CGDisplayModeRef mode) {
    NSDictionary *dict = (NSDictionary *) mode;
    unsigned depth = [[dict valueForKey: @"Depth"] unsignedIntValue];

    switch (depth) {
    case 24:
    case 32:
        return (CFStringRef) CFRetain(CFSTR(IO32BitDirectPixels));
    case 16:
        return (CFStringRef) CFRetain(CFSTR(IO16BitDirectPixels));
    default:
        return (CFStringRef) CFRetain(CFSTR(""));
    }
}

CFArrayRef CGDisplayCopyAllDisplayModes(CGDirectDisplayID displayIndex,
                                        CFDictionaryRef options)
{
    NSDisplay *display = currentDisplay();
    NSArray *modes = nil;
    if (display) {
        modes = [display modesForScreen: displayIndex - 1];
    }
    if (!modes || [modes count] == 0) {
        modes = @[ defaultDisplayMode() ];
    }
    return (CFArrayRef)[modes retain];
}

CGError CGDisplaySetDisplayMode(CGDirectDisplayID displayId,
                                CGDisplayModeRef mode, CFDictionaryRef options)
{
    NSDisplay *display = currentDisplay();
    if (!display)
        return kCGErrorInvalidConnection;
    BOOL result = [display setMode: mode forScreen: displayId - 1];

    return result ? kCGErrorSuccess : kCGErrorFailure;
}

static NSData *edidForDisplay(CGDirectDisplayID displayId) {
    NSDisplay *display = currentDisplay();
    if (!display)
        return nil;

    NSScreen *screen = screenForDisplayID([display screens], displayId);
    if (!screen)
        return nil;

    NSData *edid = [screen edid];
    if (edid && [edid length] >= 16)
        return edid;

    return nil;
}

CGSize CGDisplayScreenSize(CGDirectDisplayID display) {
    NSData *edid = edidForDisplay(display);

    if (!edid) {
        CGRect bounds = CGDisplayBounds(display);

        return bounds.size;
    }

    return (CGSize){.width = 0, .height = 0};
}

uint32_t CGDisplaySerialNumber(CGDirectDisplayID displayId) {
    NSData *edid = edidForDisplay(displayId);
    if (!edid)
        return displayId;

    return CFSwapInt32LittleToHost(*(uint32_t *) (&[edid bytes][12]));
}

uint32_t CGDisplayModelNumber(CGDirectDisplayID displayId) {
    NSData *edid = edidForDisplay(displayId);
    if (!edid)
        return kDisplayProductIDGeneric;

    return CFSwapInt16LittleToHost(*(uint16_t *) (&[edid bytes][10]));
}

uint32_t CGDisplayVendorNumber(CGDirectDisplayID displayId) {
    NSData *edid = edidForDisplay(displayId);
    if (!edid)
        return kDisplayVendorIDUnknown;

    return CFSwapInt16BigToHost(*(uint16_t *) (&[edid bytes][8]));
}

io_service_t CGDisplayIOServicePort(CGDirectDisplayID displayID) {
    // The code in this function is:
    // Copyright (c) 2002-2006 Marcus Geelnard
    // Copyright (c) 2006-2010 Camilla Berglund <elmindreda@elmindreda.org>
    // Taken from
    // https://github.com/glfw/glfw/blob/e0a6772e5e4c672179fc69a90bcda3369792ed1f/src/cocoa_monitor.m

    io_iterator_t iter;
    io_service_t serv, servicePort = 0;

    CFMutableDictionaryRef matching = IOServiceMatching("IODisplayConnect");

    // releases matching for us
    kern_return_t err =
            IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iter);
    if (err)
        return 0;

    while ((serv = IOIteratorNext(iter)) != 0) {
        CFDictionaryRef info;
        CFIndex vendorID, productID, serialNumber;
        CFNumberRef vendorIDRef, productIDRef, serialNumberRef;
        Boolean success;

        info = IODisplayCreateInfoDictionary(serv, kIODisplayOnlyPreferredName);

        vendorIDRef = CFDictionaryGetValue(info, CFSTR(kDisplayVendorID));
        productIDRef = CFDictionaryGetValue(info, CFSTR(kDisplayProductID));
        serialNumberRef =
                CFDictionaryGetValue(info, CFSTR(kDisplaySerialNumber));

        if (!vendorIDRef || !productIDRef || !serialNumberRef) {
            CFRelease(info);
            continue;
        }

        success =
                CFNumberGetValue(vendorIDRef, kCFNumberCFIndexType, &vendorID);
        success &= CFNumberGetValue(productIDRef, kCFNumberCFIndexType,
                                    &productID);
        success &= CFNumberGetValue(serialNumberRef, kCFNumberCFIndexType,
                                    &serialNumber);

        if (!success) {
            CFRelease(info);
            continue;
        }

        // If the vendor and product id along with the serial don't match
        // then we are not looking at the correct monitor.
        // NOTE: The serial number is important in cases where two monitors
        //       are the exact same.
        if (CGDisplayVendorNumber(displayID) != vendorID ||
            CGDisplayModelNumber(displayID) != productID ||
            CGDisplaySerialNumber(displayID) != serialNumber) {
            CFRelease(info);
            continue;
        }

        // The VendorID, Product ID, and the Serial Number all Match Up!
        // Therefore we have found the appropriate display io_service
        servicePort = serv;
        CFRelease(info);
        break;
    }

    IOObjectRelease(iter);
    return servicePort;
}

// The union of the active displays in CoreGraphics' global space.
static CGDisplayGeometryRect desktopBounds(NSArray<NSScreen *> *screens) {
    CGDisplayGeometryRect desktop = {0, 0, 0, 0};
    for (NSScreen *screen in screens) {
        if (NSIsEmptyRect([screen frame]))
            continue;
        CGRect rect = globalRectForFrame(screens, [screen frame]);
        desktop = CGDisplayGeometryUnion(
                desktop, (CGDisplayGeometryRect){rect.origin.x, rect.origin.y,
                                                 rect.size.width, rect.size.height});
    }
    return desktop;
}

// The one place CoreGraphics' global point meets the backend's: clip it to the
// desktop, flip it into Cocoa's space against the main display's height (the inverse
// of how the pointer is reported: -[NSDisplay mouseLocation] is Cocoa's space,
// CGEventGetLocation() the same point flipped), and hand it to -warpMouse:. The rules
// are written down in CGDisplayGeometry.h.
static CGError warpToGlobalPoint(NSDisplay *display, CGPoint point) {
    if (!isfinite(point.x) || !isfinite(point.y))
        return kCGErrorIllegalArgument;

    NSArray<NSScreen *> *screens = [display screens];
    if ([screens count] == 0)
        return kCGErrorCannotComplete;

    NSScreen *main = [screens objectAtIndex: 0];
    CGFloat scale = [main backingScaleFactor];
    if (!(scale >= 1))
        scale = 1;

    CGDisplayGeometryPoint clipped = CGDisplayGeometryClamp(
            desktopBounds(screens), scale,
            (CGDisplayGeometryPoint){point.x, point.y});
    CGDisplayGeometryPoint cocoa =
            CGDisplayGeometryFlip(NSHeight([main frame]), clipped);

    // A backend that cannot move the pointer says so instead of reporting success.
    return [display warpMouse: NSMakePoint(cocoa.x, cocoa.y)]
                   ? kCGErrorSuccess
                   : kCGErrorCannotComplete;
}

CGError CGWarpMouseCursorPosition(CGPoint newCursorPosition) {
    NSDisplay *display = currentDisplay();
    if (!display)
        return kCGErrorInvalidConnection;
    return warpToGlobalPoint(display, newCursorPosition);
}

CGError CGDisplayMoveCursorToPoint(CGDirectDisplayID displayID, CGPoint newCursorPosition) {
    NSDisplay *display = currentDisplay();
    if (!display)
        return kCGErrorInvalidConnection;

    // The point is relative to the upper-left corner of that display.
    NSArray<NSScreen *> *screens = [display screens];
    NSScreen *screen = screenForDisplayID(screens, displayID);
    if (!screen || NSIsEmptyRect([screen frame]))
        return kCGErrorIllegalArgument;

    CGRect bounds = globalRectForFrame(screens, [screen frame]);
    CGDisplayGeometryPoint global = CGDisplayGeometryDisplayToGlobal(
            (CGDisplayGeometryRect){bounds.origin.x, bounds.origin.y,
                                    bounds.size.width, bounds.size.height},
            (CGDisplayGeometryPoint){newCursorPosition.x, newCursorPosition.y});
    return warpToGlobalPoint(display, CGPointMake(global.x, global.y));
}

CGError CGAssociateMouseAndMouseCursorPosition(boolean_t connected) {
    NSDisplay *display = currentDisplay();
    if (!display)
        return kCGErrorInvalidConnection;

    // connected == false means cursor is disconnected from mouse (grab/relative mode).
    // connected == true means normal desktop cursor operation.
    [display grabMouse: !connected];
    return kCGErrorSuccess;
}

CFDictionaryRef CGDisplayBestModeForParametersAndRefreshRate(
        CGDirectDisplayID display, size_t bitsPerPixel, size_t width,
        size_t height, CGRefreshRate refreshRate, boolean_t *exactMatch)
{
    return nil;
}

boolean_t CGDisplayIsCaptured(CGDirectDisplayID display) {
    return FALSE;
}

CGError CGDisplaySwitchToMode(CGDirectDisplayID display, CFDictionaryRef mode) {
    return kCGErrorSuccess;
}

CFDictionaryRef CGDisplayCurrentMode(CGDirectDisplayID display) {
    return nil;
}

size_t CGDisplayModeGetPixelWidth(CGDisplayModeRef mode) {
    NSDictionary *dict = (NSDictionary *) mode;
    NSNumber *pixelWidth = [dict valueForKey: @"PixelWidth"];
    if (pixelWidth)
        return [pixelWidth unsignedIntValue];
    return CGDisplayModeGetWidth(mode);
}

size_t CGDisplayModeGetPixelHeight(CGDisplayModeRef mode) {
    NSDictionary *dict = (NSDictionary *) mode;
    NSNumber *pixelHeight = [dict valueForKey: @"PixelHeight"];
    if (pixelHeight)
        return [pixelHeight unsignedIntValue];
    return CGDisplayModeGetHeight(mode);
}

uint32_t CGDisplayModeGetIOFlags(CGDisplayModeRef mode) {
    NSDictionary *dict = (NSDictionary *) mode;
    return [[dict valueForKey: @"IOFlags"] unsignedIntValue];
}

boolean_t CGDisplayModeIsUsableForDesktopGUI(CGDisplayModeRef mode) {
    NSDictionary *dict = (NSDictionary *) mode;
    NSNumber *usable = [dict valueForKey: @"UsableForDesktopGUI"];
    if (usable)
        return [usable boolValue];
    return TRUE;
}

boolean_t CGDisplayIsActive(CGDirectDisplayID display) {
    uint32_t count = 0;
    if (CGGetActiveDisplayList(0, NULL, &count) == kCGErrorSuccess && count > 0) {
        CGDirectDisplayID *displays = malloc(count * sizeof(CGDirectDisplayID));
        if (displays) {
            CGGetActiveDisplayList(count, displays, &count);
            for (uint32_t i = 0; i < count; i++) {
                if (displays[i] == display) {
                    free(displays);
                    return 1;
                }
            }
            free(displays);
        }
    }
    return (display == CGMainDisplayID());
}

// The X11 and Wayland backends report no display power state, and a display
// they list stays drawable, so no display is ever reported asleep.
boolean_t CGDisplayIsAsleep(CGDirectDisplayID display) {
    return false;
}

boolean_t CGDisplayIsBuiltin(CGDirectDisplayID display) {
    return (display == CGMainDisplayID());
}

CGColorSpaceRef CGDisplayCopyColorSpace(CGDirectDisplayID display) {
    return CGColorSpaceCreateDeviceRGB();
}

int32_t CGDisplayRotation(CGDirectDisplayID display) {
    return 0;
}

CFUUIDRef CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID display) {
    UInt8 b0 = (display >> 24) & 0xff;
    UInt8 b1 = (display >> 16) & 0xff;
    UInt8 b2 = (display >> 8) & 0xff;
    UInt8 b3 = display & 0xff;
    return CFUUIDCreateWithBytes(kCFAllocatorDefault,
        b0, b1, b2, b3,
        0x11, 0x22, 0x33, 0x44,
        0x55, 0x66, 0x77, 0x88,
        0x99, 0xaa, 0xbb, 0xcc);
}

CGDirectDisplayID CGDisplayGetDisplayIDFromUUID(CFUUIDRef uuid) {
    if (!uuid) return CGMainDisplayID();
    CFUUIDBytes b = CFUUIDGetUUIDBytes(uuid);
    CGDirectDisplayID id = ((uint32_t)b.byte0 << 24) |
                           ((uint32_t)b.byte1 << 16) |
                           ((uint32_t)b.byte2 << 8) |
                           (uint32_t)b.byte3;
    if (id == 0) return CGMainDisplayID();
    return id;
}



