#ifndef CGGRADIENT_H
#define CGGRADIENT_H

#import <CoreGraphics/CGColorSpace.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CoreGraphicsExport.h>

typedef struct CGGradient *CGGradientRef;

/* CF_OPTIONS rather than CF_ENUM: these are combinable flags, not a closed set of
 * cases, which is what CF_OPTIONS is for and what the two draw calls take. The
 * practical reason to want it is on the Swift side, where a CF_OPTIONS type is
 * meant to import as an OptionSet so a caller can write `[]` and `|` instead of
 * building the value from raw initialisers.
 *
 * That import behaviour is not verified here: the Swift CoreGraphics overlay used
 * in this build is prebuilt and there is no .swiftinterface to inspect, so the
 * declaration is corrected but the Swift-side effect is unproven. The C test in
 * tests/coregraphics-gradient.c builds and passes against it either way. */
typedef CF_OPTIONS(uint32_t, CGGradientDrawingOptions) {
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
