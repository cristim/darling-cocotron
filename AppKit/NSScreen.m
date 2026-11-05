/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// Original - Christopher Lloyd <cjwl@objc.net>
#import <AppKit/NSApplication.h>
#import <AppKit/NSDisplay.h>
#import <AppKit/NSScreen.h>
#import <AppKit/NSWindow.h>

NSNotificationName const NSScreenColorSpaceDidChangeNotification = @"NSScreenColorSpaceDidChangeNotification";

// The display product name descriptor (tag 0xFC) of an EDID base block: one
// of the four 18-byte descriptors at offset 54, text ended by 0x0A and
// padded with spaces (VESA E-EDID).
static NSString *monitorNameFromEDID(NSData *edid) {
    const uint8_t *bytes = [edid bytes];
    NSUInteger length = [edid length];

    for (NSUInteger offset = 54; offset <= 108 && offset + 18 <= length;
         offset += 18) {
        const uint8_t *d = bytes + offset;
        if (d[0] != 0 || d[1] != 0 || d[3] != 0xFC)
            continue;
        NSUInteger n = 0;
        while (n < 13 && d[5 + n] != 0x0A)
            n++;
        while (n > 0 && d[5 + n - 1] == ' ')
            n--;
        if (n > 0)
            return [[[NSString alloc] initWithBytes: d + 5
                                             length: n
                                           encoding: NSASCIIStringEncoding]
                    autorelease];
    }
    return nil;
}

// One frame at the current mode's refresh rate. The backends report one
// rate per mode, so the shortest and longest intervals are the same; 60 Hz
// when the rate is unknown.
static NSTimeInterval refreshIntervalForDisplay(CGDirectDisplayID display) {
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode(display);
    double rate = mode ? CGDisplayModeGetRefreshRate(mode) : 0;

    CGDisplayModeRelease(mode);
    return 1.0 / (rate > 0 ? rate : 60.0);
}

@implementation NSScreen

- initWithFrame: (NSRect) frame visibleFrame: (NSRect) visibleFrame {
    _frame = frame;
    _visibleFrame = visibleFrame;
    return self;
}

- (void) dealloc {
    if (_edid)
        [_edid release];
    [super dealloc];
}

+ (NSScreen *) mainScreen {
    NSScreen *result = [[NSApp keyWindow] screen];

    if (result == nil)
        result = [[self screens] objectAtIndex: 0];

    return result;
}

+ (NSArray *) screens {
    return [[NSDisplay currentDisplay] screens];
}

- (NSWindowDepth) depth {
    return _depth;
}

- (NSRect) frame {
    return _frame;
}

- (NSRect) visibleFrame {
    return _visibleFrame;
}

- (CGFloat) userSpaceScaleFactor {
    return 1.0;
}

// Backends with high-resolution displays override this (WaylandScreen,
// X11Screen). A backend that has no way to know its scale stays at 1.
- (CGFloat) backingScaleFactor {
    return 1.0;
}

- (id) description {
    return [NSString stringWithFormat: @"< %@ - frame %@, visible %@ >",
                                       [super description],
                                       NSStringFromRect(_frame),
                                       NSStringFromRect(_visibleFrame)];
}

- (NSString *) localizedName {
    NSString *name = _edid ? monitorNameFromEDID(_edid) : nil;

    if (name == nil)
        name = [NSString stringWithFormat: @"Display %u",
                                           (unsigned) [self cgDirectDisplayID]];
    return name;
}

// Surfaces are presented as SDR: no headroom above 1.0, and no reference
// rendering.
- (CGFloat) maximumExtendedDynamicRangeColorComponentValue {
    return 1.0;
}

- (CGFloat) maximumPotentialExtendedDynamicRangeColorComponentValue {
    return 1.0;
}

- (CGFloat) maximumReferenceExtendedDynamicRangeColorComponentValue {
    return 0.0;
}

- (NSTimeInterval) minimumRefreshInterval {
    return refreshIntervalForDisplay([self cgDirectDisplayID]);
}

- (NSTimeInterval) maximumRefreshInterval {
    return refreshIntervalForDisplay([self cgDirectDisplayID]);
}

- (NSDictionary<NSDeviceDescriptionKey, id> *) deviceDescription {
    // AppKit clients use this documented string key to obtain the same display
    // ID used by CoreGraphics and assigned by the window-system backend.
    return @{ @"NSScreenNumber":
            [NSNumber numberWithUnsignedInt: [self cgDirectDisplayID]] };
}

@end

@implementation NSScreen (Darling)
- (NSData *) edid {
    return self->_edid;
}

- (void) setEdid: (NSData *) data {
    NSData *old = self->_edid;
    self->_edid = [data retain];
    [old release];
}

- (CGDirectDisplayID) cgDirectDisplayID {
    if (self->_directDisplayID == 0)
        return 1;
    return self->_directDisplayID;
}

- (void) setCgDirectDisplayID: (CGDirectDisplayID) displayID {
    self->_directDisplayID = displayID;
}

@end
