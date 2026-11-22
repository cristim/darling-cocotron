#import <QuartzCore/QuartzCore.h>

int main(void) {
    @autoreleasepool {
        CALayer *layer = [CALayer layer];
        if (!CGAffineTransformEqualToTransform([layer affineTransform],
                                                CGAffineTransformIdentity))
            return 1;

        CGAffineTransform affine = CGAffineTransformMake(2, 3, 4, 5, 6, 7);
        [layer setAffineTransform:affine];
        if (!CGAffineTransformEqualToTransform([layer affineTransform], affine))
            return 2;
        if (!CATransform3DEqualToTransform(layer.transform,
                                           CATransform3DMakeAffineTransform(affine)))
            return 3;

        layer.transform = CATransform3DIdentity;
        if (!CGAffineTransformEqualToTransform([layer affineTransform],
                                                CGAffineTransformIdentity))
            return 4;
        return 0;
    }
}
