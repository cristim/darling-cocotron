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

        NSColor *fromComponents = [NSColor
                colorWithColorSpace:[NSColorSpace deviceRGBColorSpace]
                        components:components count:4];
        if (fromComponents == nil ||
            !CGColorEqualToColor(fromComponents.CGColor, original))
            return 4;

        BOOL rejectedInvalidCount = NO;
        @try {
            [NSColor colorWithColorSpace:[NSColorSpace deviceRGBColorSpace]
                            components:components count:3];
        } @catch (NSException *exception) {
            rejectedInvalidCount = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        if (!rejectedInvalidCount)
            return 5;

        CGColorRelease(original);
        CGColorSpaceRelease(space);
        return 0;
    }
}
