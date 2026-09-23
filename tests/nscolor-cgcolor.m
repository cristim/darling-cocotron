#import <AppKit/AppKit.h>

int main(void) {
    @autoreleasepool {
        if ([NSColor colorWithCGColor:NULL] != nil)
            return 1;

        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {0.2, 0.4, 0.6, 0.8};
        CGColorRef original = CGColorCreate(space, components);
        NSColor *color = [NSColor colorWithCGColor:original];
        if (color == nil || !CGColorEqualToColor(color.CGColor, original))
            return 2;
        if (![color.colorSpaceName isEqualToString:NSDeviceRGBColorSpace])
            return 3;

        CGColorRelease(original);
        CGColorSpaceRelease(space);
        return 0;
    }
}
