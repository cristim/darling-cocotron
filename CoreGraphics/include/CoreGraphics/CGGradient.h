#ifndef CGGRADIENT_H
#define CGGRADIENT_H

#import <CoreGraphics/CGColorSpace.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CoreGraphicsExport.h>

typedef struct CGGradient *CGGradientRef;

typedef CF_ENUM(uint32_t, CGGradientDrawingOptions)
{
    kCGGradientDrawsBeforeStartLocation = 0x01,
    kCGGradientDrawsAfterEndLocation = 0x02
};

CGGradientRef CGGradientCreateWithColorComponents(CGColorSpaceRef colorSpace,
                                                  const CGFloat components[],
                                                  const CGFloat locations[],
                                                  size_t count);
CGGradientRef CGGradientCreateWithColors(CGColorSpaceRef colorSpace,
                                         CFArrayRef colors,
                                         const CGFloat locations[]);

void CGGradientRelease(CGGradientRef self);
CGGradientRef CGGradientRetain(CGGradientRef self);

CF_EXPORT CFTypeID CGGradientGetTypeID(void);
CF_EXPORT size_t CGGradientGetCount(CGGradientRef self);
CF_EXPORT const CGFloat *CGGradientGetLocations(CGGradientRef self);
CF_EXPORT const CGFloat *CGGradientGetColors(CGGradientRef self);
CF_EXPORT CGColorSpaceRef CGGradientGetColorSpace(CGGradientRef self);

#endif /* CGGRADIENT_H */
