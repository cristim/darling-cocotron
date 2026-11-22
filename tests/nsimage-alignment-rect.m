#import <AppKit/AppKit.h>

static BOOL equalRect(NSRect a, NSRect b) {
    return NSEqualRects(a, b);
}

int main(void) {
    @autoreleasepool {
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(20, 30)];
        if (!equalRect(image.alignmentRect, NSMakeRect(0, 0, 20, 30)))
            return 1;

        image.size = NSMakeSize(40, 50);
        if (!equalRect(image.alignmentRect, NSMakeRect(0, 0, 40, 50)))
            return 2;

        image.alignmentRect = NSMakeRect(2, 3, 15, 21);
        if (!equalRect(image.alignmentRect, NSMakeRect(2, 3, 15, 21)))
            return 3;

        image.size = NSMakeSize(60, 70);
        if (!equalRect(image.alignmentRect, NSMakeRect(2, 3, 15, 21)))
            return 4;

        NSImage *copy = [image copy];
        BOOL copied = equalRect(copy.alignmentRect, image.alignmentRect);
        [copy release];
        [image release];
        return copied ? 0 : 5;
    }
}
