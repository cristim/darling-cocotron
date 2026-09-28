#import <AppKit/AppKit.h>
#include <stdlib.h>

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
        CGContextRef bitmap = CGBitmapContextCreate(NULL, 4, 4, 8, 16, space, kCGImageAlphaPremultipliedLast);
        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithCGContext:bitmap flipped:NO];
        expect(context.CGContext == bitmap && [context graphicsPort] == bitmap, @"CGContext property");

        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(8, 6)];
        NSRect rect = NSMakeRect(0, 0, 8, 6);
        NSDictionary<NSImageHintKey, id> *hints = @{NSImageHintCTM : [NSAffineTransform transform]};
        CGImageRef cgImage = [image CGImageForProposedRect:&rect context:nil hints:hints];
        expect(cgImage != NULL && CGImageGetWidth(cgImage) == 8 && CGImageGetHeight(cgImage) == 6,
               @"CGImageForProposedRect returns an image the caller does not own");
        CGContextRelease(bitmap);
        CGColorSpaceRelease(space);
        NSLog(@"PASS: CGContext, CGImageForProposedRect and image hint keys");
    }
    return 0;
}
