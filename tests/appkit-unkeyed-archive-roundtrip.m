#import <AppKit/AppKit.h>
#include <stdio.h>
#include <math.h>

static int checkRoundTrip(id original, const char *name) {
    NSData *archive = [NSArchiver archivedDataWithRootObject: original];
    id decoded = [NSUnarchiver unarchiveObjectWithData: archive];
    if (!decoded || ![decoded isKindOfClass: [original class]]) {
        fprintf(stderr, "%s failed to round trip\n", name);
        return 0;
    }
    printf("%s PASS (%lu bytes)\n", name, (unsigned long)[archive length]);
    return 1;
}

int main(void) {
    @autoreleasepool {
        int ok = 1;
        ok &= checkRoundTrip([NSColor colorWithCalibratedRed: .2 green: .4 blue: .6 alpha: .8], "calibrated RGB");
        ok &= checkRoundTrip([NSColor colorWithDeviceWhite: .3 alpha: .7], "device white");
        ok &= checkRoundTrip([NSColor colorWithDeviceCyan: .1 magenta: .2 yellow: .3 black: .4 alpha: .5], "device CMYK");
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint: NSMakePoint(1, 2)];
        [path lineToPoint: NSMakePoint(3, 4)];
        [path curveToPoint: NSMakePoint(9, 10) controlPoint1: NSMakePoint(5, 6) controlPoint2: NSMakePoint(7, 8)];
        [path closePath];
        [path setLineWidth: 2.5];
        NSData *pathArchive = [NSArchiver archivedDataWithRootObject: path];
        NSBezierPath *decodedPath = [NSUnarchiver unarchiveObjectWithData: pathArchive];
        if (![decodedPath isKindOfClass: [NSBezierPath class]] || [decodedPath elementCount] != 4 || fabs([decodedPath lineWidth] - 2.5) > .001) {
            fprintf(stderr, "bezier path failed to round trip\n");
            ok = 0;
        } else printf("bezier path PASS (%lu bytes)\n", (unsigned long)[pathArchive length]);
        NSFont *font = [NSFont systemFontOfSize: 14];
        NSData *fontArchive = [NSArchiver archivedDataWithRootObject: font];
        NSFont *decodedFont = [NSUnarchiver unarchiveObjectWithData: fontArchive];
        if (![decodedFont isKindOfClass: [NSFont class]] || fabs([decodedFont pointSize] - 14) > .001) {
            fprintf(stderr, "font failed to round trip\n");
            ok = 0;
        } else printf("font PASS (%lu bytes)\n", (unsigned long)[fontArchive length]);
        return ok ? 0 : 1;
    }
}
