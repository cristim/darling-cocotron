/* Copyright (c) 2006-2007 Christopher J. W. Lloyd
                  2009 Markus Hitter <mah@jump-ing.de>

   Permission is hereby granted, free of charge, to any person obtaining a copy of
   this software and associated documentation files (the "Software"), to deal in
   the Software without restriction, including without limitation the rights to
   use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
   the Software, and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
   FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
   COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
   IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFRuntime.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGGradient.h>
#include <Foundation/NSString.h>
#include <stdlib.h>
#include <string.h>
#include "CGGradientPrivate.h"

static CFTypeID gradientTypeID;
static CFRuntimeClass gradientClass;

static void CGGradientFinalize(CFTypeRef cf);

CFTypeID CGGradientGetTypeID(void) {
    if (gradientTypeID == 0) {
        memset(&gradientClass, 0, sizeof(gradientClass));
        gradientClass.version = 0;
        gradientClass.className = "CGGradient";
        gradientClass.finalize = CGGradientFinalize;
        gradientTypeID = _CFRuntimeRegisterClass(&gradientClass);
    }
    return gradientTypeID;
}

static void CGGradientFinalize(CFTypeRef cf) {
    CGGradientRef gradient = (CGGradientRef)cf;

    CGColorSpaceRelease(gradient->colorSpace);
    free(gradient->locations);
    free(gradient->components);
}

/* Clamps one location into 0...1 and never below the previous one, so the stops
 * are always ordered. Core Graphics accepts out-of-range and unordered input by
 * constraining it rather than rejecting the gradient. */
static CGFloat CGGradientClampLocation(CGFloat location, CGFloat previous) {
    if (!(location >= 0.0))
        location = 0.0;
    if (location > 1.0)
        location = 1.0;
    if (location < previous)
        location = previous;
    return location;
}

static CFTypeRef CGGradientCreate(CGColorSpaceRef colorSpace,
                                  const CGFloat *components,
                                  const CGFloat *locations, size_t count,
                                  size_t numberOfComponents) {
    CGGradientRef gradient;
    size_t i, j;
    CGFloat previousLocation = 0.0;

    if (count == 0)
        return NULL;
    if (numberOfComponents == 0 || numberOfComponents > CGGradientMaximumComponents)
        return NULL;

    gradient = (CGGradientRef)_CFRuntimeCreateInstance(
            NULL, CGGradientGetTypeID(), sizeof(struct CGGradient),
            NULL);
    if (gradient == NULL)
        return NULL;

    gradient->colorSpace = (CGColorSpaceRef)CGColorSpaceRetain(colorSpace);
    gradient->count = count;
    gradient->numberOfComponents = numberOfComponents;
    gradient->locations = (CGFloat *)calloc(count, sizeof(CGFloat));
    gradient->components = (CGFloat *)calloc(count * numberOfComponents,
                                             sizeof(CGFloat));
    if (gradient->locations == NULL || gradient->components == NULL) {
        CGGradientRelease(gradient);
        return NULL;
    }

    for (i = 0; i < count; i++) {
        for (j = 0; j < numberOfComponents; j++) {
            gradient->components[i * numberOfComponents + j] =
                    components[i * numberOfComponents + j];
        }
    }

    if (locations != NULL) {
        for (i = 0; i < count; i++) {
            previousLocation = CGGradientClampLocation(locations[i],
                                                      previousLocation);
            gradient->locations[i] = previousLocation;
        }
    } else if (count == 1) {
        gradient->locations[0] = 0.0;
    } else {
        /* No locations given: divide the gradient evenly. */
        for (i = 0; i < count; i++) {
            gradient->locations[i] = (CGFloat)i / (CGFloat)(count - 1);
        }
    }

    return gradient;
}

CGGradientRef CGGradientCreateWithColorComponents(CGColorSpaceRef colorSpace,
                                                  const CGFloat components[],
                                                  const CGFloat locations[],
                                                  size_t count) {
    size_t numberOfComponents;

    if (colorSpace == NULL || components == NULL)
        return NULL;

    numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace) + 1;

    return (CGGradientRef)CGGradientCreate(colorSpace, components, locations,
                                           count, numberOfComponents);
}

CGGradientRef CGGradientCreateWithColors(CGColorSpaceRef colorSpace,
                                         CFArrayRef colors,
                                         const CGFloat locations[]) {
    CFIndex i, count;
    size_t numberOfComponents;
    CGFloat *components;
    CGGradientRef gradient;

    if (colorSpace == NULL || colors == NULL)
        return NULL;

    count = CFArrayGetCount(colors);
    if (count == 0)
        return NULL;

    numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace) + 1;
    if (numberOfComponents > CGGradientMaximumComponents)
        return NULL;

    components = (CGFloat *)calloc((size_t)count * numberOfComponents,
                                   sizeof(CGFloat));
    if (components == NULL)
        return NULL;

    for (i = 0; i < count; i++) {
        CGColorRef color = (CGColorRef)CFArrayGetValueAtIndex(colors, i);
        size_t checkNumberOfComponents, j;

        if (color == NULL ||
            CGColorGetColorSpace(color) == NULL) {
            NSLog(@"CGGradientCreateWithColors, colour %ld is null or has no "
                  @"colour space", (long)i);
            free(components);
            return NULL;
        }

        checkNumberOfComponents = CGColorGetNumberOfComponents(color);
        if (checkNumberOfComponents != numberOfComponents) {
            /* Core Graphics converts a colour into the gradient's space here.
             * There is no colour conversion in CoreGraphics yet, and guessing
             * would produce wrong colours, so refuse instead. */
            NSLog(@"CGGradientCreateWithColors, colour %ld has %zu components "
                  @"but the gradient's space has %zu, and colour conversion is "
                  @"not implemented", (long)i, checkNumberOfComponents,
                  numberOfComponents);
            free(components);
            return NULL;
        }

        {
            const CGFloat *copy = CGColorGetComponents(color);
            for (j = 0; j < numberOfComponents; j++)
                components[(size_t)i * numberOfComponents + j] = copy[j];
        }
    }

    gradient = (CGGradientRef)CGGradientCreate(colorSpace, components, locations,
                                               (size_t)count,
                                               numberOfComponents);
    free(components);
    return gradient;
}

void CGGradientColorAtLocation(CGGradientRef gradient, CGFloat t,
                               CGFloat *components) {
    size_t i, j, n = gradient->numberOfComponents;
    size_t stop;
    CGFloat start, end, fraction;

    /* The last stop at or before t, so that coincident stops resolve to the
     * earlier colour instead of dividing by a zero-length span. */
    stop = 0;
    for (i = 1; i < gradient->count; i++) {
        if (gradient->locations[i] > t)
            break;
        stop = i;
    }

    if (stop + 1 >= gradient->count) {
        memcpy(components, gradient->components + stop * n, n * sizeof(CGFloat));
        return;
    }

    start = gradient->locations[stop];
    end = gradient->locations[stop + 1];
    if (end <= start) {
        memcpy(components, gradient->components + stop * n, n * sizeof(CGFloat));
        return;
    }

    fraction = (t - start) / (end - start);
    if (fraction < 0.0)
        fraction = 0.0;
    else if (fraction > 1.0)
        fraction = 1.0;

    for (j = 0; j < n; j++) {
        CGFloat from = gradient->components[stop * n + j];
        CGFloat to = gradient->components[(stop + 1) * n + j];
        components[j] = from + (to - from) * fraction;
    }
}

void CGGradientRelease(CGGradientRef self) {
    if (self == NULL)
        return;
    CFRelease((CFTypeRef)self);
}

CGGradientRef CGGradientRetain(CGGradientRef self) {
    if (self == NULL)
        return NULL;
    return (CGGradientRef)CFRetain((CFTypeRef)self);
}
