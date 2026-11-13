// CGContextGetLineDashCount/Pattern read back what CGContextSetLineDash stored,
// CGStyleRetain and CGStyleRelease balance, CGStyleEqualToStyle compares identity,
// and the CGS update-token and window-transform calls return success.
#import <AppKit/AppKit.h>
#import <CoreGraphics/CGSServerSPI.h>
#include <stdlib.h>

extern void *CGStyleCreateShadow(void *parameters, void *unused);
extern void *CGStyleRetain(void *style);
extern bool CGStyleEqualToStyle(void *a, void *b);
extern void CGStyleRelease(void *style);

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(NULL, 8, 8, 8, 32, space, kCGImageAlphaPremultipliedLast);
        expect(context != NULL, @"a bitmap context exists");

        expect(CGContextGetLineDashCount(context) == 0, @"a new context has a solid line");
        CGFloat lengths[3] = {4, 2, 1};
        CGContextSetLineDash(context, 0, lengths, 3);
        expect(CGContextGetLineDashCount(context) == 3, @"the count is the number of lengths set");
        CGFloat back[3] = {0, 0, 0};
        CGContextGetLineDashPattern(context, back);
        expect(back[0] == 4 && back[1] == 2 && back[2] == 1, @"the pattern reads back");
        CGContextSaveGState(context);
        CGContextSetLineDash(context, 0, NULL, 0);
        expect(CGContextGetLineDashCount(context) == 0, @"clearing the dash empties the count");
        CGContextRestoreGState(context);
        expect(CGContextGetLineDashCount(context) == 3, @"the dash is part of the saved state");
        CGContextSetFontSmoothingBackgroundColor(context, NULL);

        void *style = CGStyleCreateShadow(NULL, NULL);
        void *other = CGStyleCreateShadow(NULL, NULL);
        expect(style != NULL && other != NULL, @"styles exist");
        expect(CGStyleEqualToStyle(style, style), @"a style equals itself");
        expect(!CGStyleEqualToStyle(style, other), @"two styles are distinct");
        expect(CGStyleRetain(style) == style, @"retain returns the style");
        CGStyleRelease(style);
        expect(CGStyleEqualToStyle(style, style), @"the style survives one release after a retain");
        CGStyleRelease(style);
        CGStyleRelease(other);

        CGSConnectionID connection = CGSMainConnectionID();
        expect(CGSDisableUpdateToken(connection) == kCGErrorSuccess, @"disable update token succeeds");
        expect(CGSReenableUpdateToken(connection) == kCGErrorSuccess, @"reenable update token succeeds");
        expect(CGSSetWindowTransform(connection, 1, CGAffineTransformIdentity) == kCGErrorSuccess,
               @"set window transform succeeds");

        CGContextRelease(context);
        CGColorSpaceRelease(space);
        NSLog(@"PASS: line dash and style");
    }
    return 0;
}
