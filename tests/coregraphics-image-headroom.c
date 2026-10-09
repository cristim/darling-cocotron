#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/CoreGraphicsPrivate.h>
#include <stdio.h>
#include <stdlib.h>

// CGImageGetHeadroom is exported, reports no headroom for an image that records none, and
// leaves the caller with a defined zero rather than an uninitialised value.
int main(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 2, 2, 8, 8, space, kCGImageAlphaPremultipliedLast);
    CGImageRef image = CGBitmapContextCreateImage(context);
    if (image == NULL) {
        fprintf(stderr, "FAIL: no image\n");
        return 1;
    }

    float headroom = 123.0f;
    if (CGImageGetHeadroom(image, &headroom) || headroom != 0.0f) {
        fprintf(stderr, "FAIL: got headroom %f, expected false and 0\n", headroom);
        return 1;
    }
    if (CGImageGetHeadroom(image, NULL)) {
        fprintf(stderr, "FAIL: NULL out pointer\n");
        return 1;
    }

    headroom = 123.0f;
    if (CGImageGetHeadroom(NULL, &headroom) || headroom != 0.0f) {
        fprintf(stderr, "FAIL: NULL image, got headroom %f, expected false and 0\n", headroom);
        return 1;
    }

    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    printf("PASS: CGImageGetHeadroom\n");
    return 0;
}
