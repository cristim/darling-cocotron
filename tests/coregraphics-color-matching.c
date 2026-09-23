#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdio.h>

static int near(CGColorRef color, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    if (color == NULL || CGColorGetNumberOfComponents(color) != 4)
        return 0;
    const CGFloat *c = CGColorGetComponents(color);
    int ok = fabs(c[0] - r) < 1e-3 && fabs(c[1] - g) < 1e-3 && fabs(c[2] - b) < 1e-3 && fabs(c[3] - a) < 1e-9;
    if (!ok)
        printf("got %f %f %f %f\n", c[0], c[1], c[2], c[3]);
    return ok;
}

static CGColorRef make(CFStringRef name, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(name);
    CGFloat components[4] = {r, g, b, a};
    CGColorRef color = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    return color;
}

static CGColorRef match(CFStringRef name, CGColorRef color) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(name);
    CGColorRef result = CGColorCreateCopyByMatchingToColorSpace(space, kCGRenderingIntentDefault, color, NULL);
    CGColorSpaceRelease(space);
    return result;
}

int main(void) {
    CGColorSpaceRef pq = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_PQ);
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGColorSpaceRef device = CGColorSpaceCreateDeviceRGB();
    if (!CGColorSpaceUsesITUR_2100TF(pq) || CGColorSpaceUsesITUR_2100TF(srgb) || CGColorSpaceUsesITUR_2100TF(device))
        return 1;
    if (CGColorSpaceIsHLGBased(pq) || CGColorSpaceIsHLGBased(srgb) || CGColorSpaceIsHLGBased(device))
        return 2;

    CGColorRef red = make(kCGColorSpaceSRGB, 1, 0, 0, 0.5);
    if (!near(match(kCGColorSpaceDisplayP3, red), 0.9175, 0.2003, 0.1386, 0.5))
        return 3;

    CGColorRef p3Red = make(kCGColorSpaceDisplayP3, 1, 0, 0, 1);
    if (!near(match(kCGColorSpaceExtendedSRGB, p3Red), 1.0931, -0.2267, -0.1501, 1))
        return 4;
    if (!near(match(kCGColorSpaceSRGB, p3Red), 1, 0, 0, 1))
        return 5;

    CGColorRef mid = make(kCGColorSpaceSRGB, 0.5, 0.5, 0.5, 1);
    if (!near(match(kCGColorSpaceLinearSRGB, mid), 0.2140, 0.2140, 0.2140, 1))
        return 6;
    if (!near(match(kCGColorSpaceExtendedSRGB, CGColorCreateGenericGray(0.5, 0.25)), 0.5, 0.5, 0.5, 0.25))
        return 7;
    if (!near(match(kCGColorSpaceSRGB, CGColorCreateGenericRGB(0.2, 0.4, 0.6, 1)), 0.2, 0.4, 0.6, 1))
        return 8;

    if (match(kCGColorSpaceSRGB, CGColorCreateGenericCMYK(0, 0, 0, 1, 1)) != NULL)
        return 9;
    if (match(kCGColorSpaceITUR_2100_PQ, red) != NULL)
        return 10;
    return 0;
}
