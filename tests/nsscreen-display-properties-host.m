// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Runs NSScreen's display properties from AppKit/NSScreen.m in a mock NSScreen.
 *
 * Apple's NSScreen documentation: maximumPotentialExtendedDynamicRangeColorComponentValue is 1.0 when the screen
 * does not support EDR, maximumExtendedDynamicRangeColorComponentValue is 1.0 when no content provides EDR, and
 * maximumReferenceExtendedDynamicRangeColorComponentValue is 0 when the display does not support reference
 * rendering. minimumRefreshInterval / maximumRefreshInterval are the shortest / longest frame times in seconds
 * (highest / lowest refresh rate). localizedName is the display's name; the EDID display product name descriptor
 * (tag 0xFC, VESA E-EDID) is where a monitor states it. */
#include <objc/runtime.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef double CGFloat;
typedef double NSTimeInterval;
typedef unsigned long NSUInteger;
typedef uint32_t CGDirectDisplayID;
typedef struct Mode *CGDisplayModeRef;
enum { NSASCIIStringEncoding = 1 };

static double modeRate;
static int modesLive;
static CGDirectDisplayID askedDisplay;
static CGDisplayModeRef CGDisplayCopyDisplayMode(CGDirectDisplayID d)
{
    askedDisplay = d;
    modesLive++;
    return (CGDisplayModeRef)malloc(1);
}
static double CGDisplayModeGetRefreshRate(CGDisplayModeRef m) { return modeRate; }
static void CGDisplayModeRelease(CGDisplayModeRef m) { if (m) { modesLive--; free(m); } }

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc; - (id)init; - (id)autorelease;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { return self; }
- (id)autorelease { return self; }
@end

__attribute__((objc_root_class))
@interface NSConstantString { Class isa; const char *_s; unsigned _len; } - (const char *)UTF8String; @end
@implementation NSConstantString - (const char *)UTF8String { return _s; } @end

@interface NSString : NSObject { char _s[64]; }
- (id)initWithBytes:(const void *)b length:(NSUInteger)n encoding:(NSUInteger)e;
+ (id)stringWithFormat:(id)format, ...;
- (const char *)UTF8String;
@end
@implementation NSString
- (id)initWithBytes:(const void *)b length:(NSUInteger)n encoding:(NSUInteger)e
{
    if (e != NSASCIIStringEncoding || n >= sizeof _s) return nil;
    memcpy(_s, b, n); _s[n] = 0;
    return self;
}
+ (id)stringWithFormat:(id)format, ...
{
    NSString *r = [[self alloc] init];
    va_list ap;
    va_start(ap, format);
    vsnprintf(r->_s, sizeof r->_s, [format UTF8String], ap);
    va_end(ap);
    return r;
}
- (const char *)UTF8String { return _s; }
@end

@interface NSData : NSObject { @public const void *_b; NSUInteger _n; } - (const void *)bytes; - (NSUInteger)length; @end
@implementation NSData - (const void *)bytes { return _b; } - (NSUInteger)length { return _n; } @end

@interface NSScreen : NSObject {
@public
    NSData *_edid;
    CGDirectDisplayID _directDisplayID;
}
- (CGDirectDisplayID)cgDirectDisplayID;
@end

@implementation NSScreen
- (CGDirectDisplayID)cgDirectDisplayID { return _directDisplayID ? _directDisplayID : 1; }
@end
#if HAVE_METHODS
@implementation NSScreen (UnderTest)
#include METHODS_INC
@end
#endif

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static void descriptor(uint8_t *edid, int slot, uint8_t tag, const char *text)
{
    uint8_t *d = edid + 54 + 18 * slot;
    memset(d, 0, 18);
    d[3] = tag;
    memset(d + 5, ' ', 13);
    size_t n = strlen(text);
    memcpy(d + 5, text, n);
    if (n < 13) d[5 + n] = 0x0A;
}

int main(void)
{
#if !HAVE_METHODS
    CK(0, "NSScreen.m implements localizedName, the three EDR values and the two refresh intervals");
#else
    NSScreen *screen = [[NSScreen alloc] init];
    id s = screen;
    screen->_directDisplayID = 3;

    CK([s maximumPotentialExtendedDynamicRangeColorComponentValue] == 1.0, "no EDR support: potential maximum 1.0");
    CK([s maximumExtendedDynamicRangeColorComponentValue] == 1.0, "no EDR content: current maximum 1.0");
    CK([s maximumReferenceExtendedDynamicRangeColorComponentValue] == 0.0, "no reference rendering: 0 (got %g)",
       [s maximumReferenceExtendedDynamicRangeColorComponentValue]);

    modeRate = 144.0;
    CK([s minimumRefreshInterval] == 1.0 / 144.0 && [s maximumRefreshInterval] == 1.0 / 144.0,
       "refresh intervals follow the current mode's rate (got %g, %g)", [s minimumRefreshInterval],
       [s maximumRefreshInterval]);
    CK(askedDisplay == 3, "the mode asked for is this screen's display (got %u)", askedDisplay);
    CK(modesLive == 0, "every display mode copied is released (%d left)", modesLive);
    modeRate = 0;
    CK([s minimumRefreshInterval] == 1.0 / 60.0, "an unknown rate falls back to 60 Hz (got %g)", [s minimumRefreshInterval]);

    CK(strcmp([[s localizedName] UTF8String], "Display 3") == 0, "no EDID: a name from the display number (got %s)",
       [[s localizedName] UTF8String]);
    uint8_t edid[128] = { 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00 };
    descriptor(edid, 0, 0xFF, "SERIAL123");
    descriptor(edid, 1, 0xFC, "DELL U2720Q");
    NSData *data = [[NSData alloc] init];
    data->_b = edid; data->_n = sizeof edid;
    screen->_edid = data;
    CK(strcmp([[s localizedName] UTF8String], "DELL U2720Q") == 0, "the EDID product name, not the serial (got %s)",
       [[s localizedName] UTF8String]);
    descriptor(edid, 1, 0xFC, "THIRTEENCHARS");
    CK(strcmp([[s localizedName] UTF8String], "THIRTEENCHARS") == 0, "a 13-character name has no terminator (got %s)",
       [[s localizedName] UTF8String]);
    data->_n = 60;
    CK(strcmp([[s localizedName] UTF8String], "Display 3") == 0, "a truncated EDID is not read past its end (got %s)",
       [[s localizedName] UTF8String]);
#endif
    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
