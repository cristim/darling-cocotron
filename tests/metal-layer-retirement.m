#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <QuartzCore/CAMetalDrawable.h>
#include <stdio.h>

static BOOL blue;

@interface RetirementMetalView : NSView @end
@implementation RetirementMetalView
+ (Class)layerClass { return [CAMetalLayer class]; }
- (CALayer *)makeBackingLayer { return [[[self class] layerClass] layer]; }
- (BOOL)wantsUpdateLayer { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)keyDown:(NSEvent *)event {
    if ([event.characters isEqualToString:@"b"]) { blue = YES; puts("INPUT blue"); fflush(stdout); }
}
@end

@interface RetirementDriver : NSObject {
    CAMetalLayer *_layer;
    id<MTLCommandQueue> _queue;
    unsigned _frames;
}
- (id)initWithLayer:(CAMetalLayer *)layer;
@end
@implementation RetirementDriver
- (id)initWithLayer:(CAMetalLayer *)layer {
    if ((self = [super init])) {
        _layer = [layer retain];
        _queue = [_layer.device newCommandQueue];
    }
    return self;
}
- (void)dealloc { [_queue release]; [_layer release]; [super dealloc]; }
- (void)frame:(NSTimer *)timer {
    id<CAMetalDrawable> drawable = [_layer nextDrawable];
    if (!drawable) { fprintf(stderr, "FAIL no drawable\n"); [NSApp terminate:nil]; return; }
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(blue ? 0 : 1, 0, blue ? 1 : 0, 1);
    id<MTLCommandBuffer> command = [_queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    [encoder endEncoding];
    [command presentDrawable:drawable];
    [command commit];
    [command waitUntilCompleted];
    if (++_frames == 3) { puts("CAPTURE_READY red=300x200"); fflush(stdout); }
}
@end

int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 200)
            styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
    root.wantsLayer = YES;
    [window setContentView:root];
    RetirementMetalView *view = [[RetirementMetalView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
    view.wantsLayer = YES;
    [root addSubview:view];
    CAMetalLayer *layer = (CAMetalLayer *)view.layer;
    layer.device = MTLCreateSystemDefaultDevice();
    layer.drawableSize = CGSizeMake(300, 200);
    if (!layer.device) { fputs("FAIL no Metal device\n", stderr); return 1; }
    [window makeFirstResponder:view];
    [window makeKeyAndOrderFront:nil];
    RetirementDriver *driver = [[RetirementDriver alloc] initWithLayer:layer];
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:driver selector:@selector(frame:) userInfo:nil repeats:YES];
    [NSApp run];
    [driver release]; [view release]; [root release]; [window release];
} }
