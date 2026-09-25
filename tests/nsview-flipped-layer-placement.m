#import <AppKit/AppKit.h>

@interface FlippedView : NSView
@end

@implementation FlippedView
- (BOOL)isFlipped { return YES; }
@end

static BOOL layerIsAt(NSView *view, CGFloat x, CGFloat y) {
    return NSEqualRects([[view layer] frame], NSMakeRect(x, y, 30, 10));
}

int main(void) {
    @autoreleasepool {
        NSView *parent = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)];
        NSView *child = [[NSView alloc] initWithFrame:NSMakeRect(10, 20, 30, 10)];
        [parent setWantsLayer:YES];
        [child setWantsLayer:YES];
        [parent addSubview:child];
        if (!layerIsAt(child, 10, 20)) return 1;

        [child removeFromSuperview];
        [parent release];
        parent = [[FlippedView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)];
        [parent setWantsLayer:YES];
        [parent addSubview:child];
        if (!layerIsAt(child, 10, 70)) return 2;

        [child setFrameOrigin:NSMakePoint(15, 40)];
        if (!layerIsAt(child, 15, 50)) return 3;

        [parent setFrameSize:NSMakeSize(200, 120)];
        if (!layerIsAt(child, 15, 70)) return 4;

        [child release];
        [parent release];
        return 0;
    }
}
