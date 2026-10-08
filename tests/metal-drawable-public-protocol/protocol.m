#import <QuartzCore/CAMetalLayer.h>

id<MTLTexture> drawableTexture(CAMetalLayer *layer) {
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    [drawable present];
    return drawable.texture;
}
