/*
 * Gradient regression for CoreGraphics.
 *
 * Covers the three things a gradient has to get right, all through the public
 * API and by reading back pixels, so a change that keeps the API shape but
 * paints a flat fill still fails:
 *
 *   - colour components: stops created from components and from CGColors carry
 *     the components they were given, and a single stop paints that colour.
 *   - interpolation: a linear gradient's colour varies between its stops and
 *     lands on the average of two stops at the midpoint.
 *   - radial falloff: the colour depends on the distance from the centre, not
 *     on x or y alone.
 *
 * Also covers the drawing options that decide whether the gradient paints beyond
 * its own start and end, and that painting is limited to the current clip.
 *
 * Exit codes are distinct per failure so a run identifies what broke.
 */
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFString.h>
#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define WIDTH 64
#define HEIGHT 32

typedef struct {
    unsigned char r, g, b, a;
} Pixel;

static Pixel pixelAt(CGContextRef context, size_t x, size_t y) {
    unsigned char *base = (unsigned char *)CGBitmapContextGetData(context);
    size_t stride = CGBitmapContextGetBytesPerRow(context);
    unsigned char *p = base + y * stride + x * 4;
    Pixel pixel;
    /* The context is premultiplied-first and 32-bit little-endian, so the bytes
     * are b, g, r, a. That is the layout tests/image-resampling.m already
     * relies on, so this follows it rather than assuming a different one. Every
     * colour used here is opaque, so premultiplication does not rescale them. */
    pixel.b = p[0];
    pixel.g = p[1];
    pixel.r = p[2];
    pixel.a = p[3];
    return pixel;
}

static CGContextRef createContext(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
            NULL, WIDTH, HEIGHT, 8, 0, space,
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    if (context != NULL)
        CGContextSetShouldAntialias(context, false);
    return context;
}

/* Gradient geometry is in CoreGraphics user space, where y grows upward, while a
 * bitmap's first row is its top row; and a pixel's centre sits at the half
 * integer coordinate of that pixel. Both conversions live here so the tests
 * cannot silently assert the wrong end of a gradient, and so an axis whose ends
 * are pixel centres actually lands on painted pixels. */
static Pixel pixelAtCGPoint(CGContextRef context, CGPoint point) {
    size_t column = (size_t)point.x;
    size_t row = (size_t)(HEIGHT - 1 - (int)point.y);
    return pixelAt(context, column, row);
}

static int near(int a, int b, int tolerance) {
    return abs(a - b) <= tolerance;
}

static int pixelNear(Pixel pixel, int r, int g, int b, int tolerance) {
    return near(pixel.r, r, tolerance) && near(pixel.g, g, tolerance) &&
           near(pixel.b, b, tolerance);
}

static void report(const char *what, Pixel pixel) {
    fprintf(stderr, "%s: %u,%u,%u,%u\n", what, pixel.r, pixel.g, pixel.b, pixel.a);
}

/* Counts distinct colours along one line of pixels, which is how a flat fill is
 * told apart from a real gradient. A gradient paints across the axis, so the
 * line has to be the one the axis runs along. */
static int countDistinct(Pixel *pixels, int length) {
    unsigned char seen[HEIGHT * WIDTH][3];
    int count = 0;
    int i;

    for (i = 0; i < length; i++) {
        Pixel pixel = pixels[i];
        int j, found = 0;
        for (j = 0; j < count; j++) {
            if (seen[j][0] == pixel.r && seen[j][1] == pixel.g &&
                seen[j][2] == pixel.b) {
                found = 1;
                break;
            }
        }
        if (!found) {
            if (count >= (int)(sizeof(seen) / sizeof(seen[0])))
                return count;
            seen[count][0] = pixel.r;
            seen[count][1] = pixel.g;
            seen[count][2] = pixel.b;
            count++;
        }
    }
    return count;
}

static int distinctColoursAcrossRow(CGContextRef context, size_t y, size_t fromX,
                                    size_t toX) {
    Pixel pixels[WIDTH];
    size_t x;
    int length = 0;

    for (x = fromX; x <= toX; x++)
        pixels[length++] = pixelAt(context, x, y);
    return countDistinct(pixels, length);
}

static int distinctColoursDownColumn(CGContextRef context, size_t x) {
    Pixel pixels[HEIGHT];
    size_t row;

    for (row = 0; row < HEIGHT; row++)
        pixels[row] = pixelAt(context, x, row);
    return countDistinct(pixels, (int)HEIGHT);
}

/* 1: components and single-stop gradients. */
static int testComponents(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 0.0, 0.0, 1.0, 1.0 }; /* opaque blue */
    CGFloat locations[] = { 0.0 };
    CGGradientRef gradient;
    CGContextRef context;
    Pixel pixel;
    int status = 0;

    gradient = CGGradientCreateWithColorComponents(space, components, locations,
                                                  1);
    if (gradient == NULL) {
        fprintf(stderr, "CGGradientCreateWithColorComponents returned NULL\n");
        CGColorSpaceRelease(space);
        return 1;
    }

    context = createContext();
    if (context == NULL) {
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        return 1;
    }

    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, HEIGHT / 2),
                                CGPointMake(WIDTH, HEIGHT / 2), 0);
    pixel = pixelAt(context, WIDTH / 2, HEIGHT / 2);
    report("single stop, centre", pixel);
    if (!pixelNear(pixel, 0, 0, 255, 2)) {
        fprintf(stderr, "a one-stop gradient did not paint its own colour\n");
        status = 2;
    }

    CGContextRelease(context);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    return status;
}

/* 3: stops created from CGColors carry the right components. Two colours with
 * the same component count but different values is what caught the original
 * copy from uninitialised memory. */
static int testColors(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat first[] = { 1.0, 0.0, 0.0, 1.0 }; /* opaque red */
    CGFloat second[] = { 0.0, 1.0, 0.0, 1.0 }; /* opaque green */
    CGColorRef colorFirst = CGColorCreate(space, first);
    CGColorRef colorSecond = CGColorCreate(space, second);
    const void *colors[] = { colorFirst, colorSecond };
    CFArrayRef array = CFArrayCreate(NULL, colors, 2, NULL);
    CGGradientRef gradient;
    CGContextRef context;
    Pixel start, end;
    int status = 0;

    /* An array element that is not a colour must be refused, not read as one:
     * the accessor would be handed something that is not a colour and would
     * read whatever happens to be at that address. */
    {
        CFTypeRef notAColor = (CFTypeRef)CFStringCreateWithCString(
                NULL, "not a colour", kCFStringEncodingUTF8);
        const void *mixed[] = { colorFirst, notAColor };
        const void *allColours[] = { colorFirst, colorSecond };
        CFArrayRef mixedArray = CFArrayCreate(NULL, mixed, 2, NULL);
        CFArrayRef goodArray = CFArrayCreate(NULL, allColours, 2, NULL);
        CGGradientRef refused = CGGradientCreateWithColors(space, mixedArray, NULL);
        CGGradientRef control = CGGradientCreateWithColors(space, goodArray, NULL);

        /* Differential: the same array with the string removed has to be
         * accepted, so a refusal above is attributable to the element's type
         * rather than to the array, the count or the space. */
        if (control == NULL) {
            fprintf(stderr, "the control array of two colours was refused, so "
                            "the mixed-array result proves nothing\n");
            status = 3;
        } else {
            CGGradientRelease(control);
        }

        if (refused != NULL) {
            fprintf(stderr, "a non-colour in the array was accepted\n");
            status = 3;
            CGGradientRelease(refused);
        }
        CFRelease(goodArray);
        CFRelease(mixedArray);
        CFRelease(notAColor);
    }

    gradient = CGGradientCreateWithColors(space, array, NULL);
    if (gradient == NULL) {
        fprintf(stderr, "CGGradientCreateWithColors returned NULL\n");
        status = 3;
        goto cleanup;
    }

    context = createContext();
    if (context == NULL) {
        status = 3;
        goto cleanup;
    }

    /* A short axis whose ends are the centres of two pixels, so the first and
     * last stops land on painted pixels rather than past them. */
    {
        CGFloat y = (CGFloat)HEIGHT / 2;
        CGContextDrawLinearGradient(context, gradient, CGPointMake(4.5, y),
                                    CGPointMake(8.5, y), 0);
        start = pixelAtCGPoint(context, CGPointMake(4.5, y));
        end = pixelAtCGPoint(context, CGPointMake(8.5, y));
    }
    report("colours: start", start);
    report("colours: end", end);
    if (!pixelNear(start, 255, 0, 0, 3)) {
        fprintf(stderr, "the first CGColor was not used for the first stop\n");
        status = 3;
    }
    if (!pixelNear(end, 0, 255, 0, 3)) {
        fprintf(stderr, "the second CGColor was not used for the second stop\n");
        status = 3;
    }
    CGContextRelease(context);

cleanup:
    CGGradientRelease(gradient);
    CFRelease(array);
    CGColorRelease(colorFirst);
    CGColorRelease(colorSecond);
    CGColorSpaceRelease(space);
    return status;
}

/* 5: interpolation along a linear gradient, and 6: locations are respected. */
static int testLinearInterpolation(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 1.0, 0.0, 0.0, 1.0, /* opaque red */
                             0.0, 0.0, 1.0, 1.0 }; /* opaque blue */
    CGFloat locations[] = { 0.0, 1.0 };
    CGGradientRef gradient =
            CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextRef context;
    Pixel start, middle, end;
    int status = 0;
    int variation;

    if (gradient == NULL)
        return 1;

    context = createContext();
    if (context == NULL) {
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        return 1;
    }

    /* A vertical axis down the middle column, so each row is one gradient
     * position and no axis-length or sampling effect can hide a flat fill. */
    {
        CGFloat bottom = 0.5, top = HEIGHT - 0.5;
        CGContextDrawLinearGradient(context, gradient,
                                    CGPointMake(WIDTH / 2, bottom),
                                    CGPointMake(WIDTH / 2, top), 0);
        start = pixelAtCGPoint(context, CGPointMake(WIDTH / 2, bottom));
        middle = pixelAtCGPoint(context,
                                CGPointMake(WIDTH / 2, (bottom + top) / 2));
        end = pixelAtCGPoint(context, CGPointMake(WIDTH / 2, top));
    }
    report("linear: start", start);
    report("linear: middle", middle);
    report("linear: end", end);

    if (!pixelNear(start, 255, 0, 0, 4)) {
        fprintf(stderr, "the linear gradient's start is not the first stop\n");
        status = 5;
    }
    if (!pixelNear(end, 0, 0, 255, 4)) {
        fprintf(stderr, "the linear gradient's end is not the last stop\n");
        status = 5;
    }
    /* Half way along the axis the colour has to be between the stops, not either
     * of them. Both channels move, so an implementation that only ever paints a
     * stop colour, or that swaps the stops, cannot pass. */
    if (!near(middle.r, 128, 24) || !near(middle.b, 128, 24) ||
        !near(middle.g, 0, 6)) {
        fprintf(stderr,
                "the linear gradient did not interpolate at the midpoint\n");
        status = 5;
    }

    /* The axis runs down a column, so the colours must vary down that column. */
    variation = distinctColoursDownColumn(context, WIDTH / 2);
    if (variation < 8) {
        fprintf(stderr,
                "a linear gradient along a column produced %d distinct "
                "colours, so the gradient is a flat fill\n",
                variation);
        status = 5;
    }

    CGContextRelease(context);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    return status;
}

/* 7: a location array that starts late shifts where the first stop appears. */
static int testLocations(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 1.0, 0.0, 0.0, 1.0, /* opaque red */
                             0.0, 0.0, 1.0, 1.0 }; /* opaque blue */
    /* The first stop sits at the axis midpoint, so the midpoint has to be red
     * and only the second half of the axis moves from red to blue. */
    CGFloat locations[] = { 0.5, 1.0 };
    CGGradientRef gradient =
            CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextRef context;
    Pixel start, middle, end;
    int status = 0;

    if (gradient == NULL)
        return 1;

    context = createContext();
    if (context == NULL) {
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        return 1;
    }

    {
        CGFloat bottom = 0.5, top = HEIGHT - 0.5;
        CGFloat midpoint = (bottom + top) / 2;
        CGContextDrawLinearGradient(context, gradient,
                                    CGPointMake(WIDTH / 2, bottom),
                                    CGPointMake(WIDTH / 2, top), 0);
        /* The first stop is at 0.5 of the axis, so the axis start and the
         * midpoint both hold it and only the run above the midpoint blends. */
        start = pixelAtCGPoint(context, CGPointMake(WIDTH / 2, bottom));
        middle = pixelAtCGPoint(context, CGPointMake(WIDTH / 2, midpoint));
        end = pixelAtCGPoint(context, CGPointMake(WIDTH / 2, top));
    }
    report("locations: start", start);
    report("locations: middle", middle);
    report("locations: end", end);

    /* The first stop's location is 0.5, so everything from the axis start up to
     * the midpoint is that stop's colour and the blend only begins after it. */
    if (!pixelNear(start, 255, 0, 0, 4) || !pixelNear(middle, 255, 0, 0, 6)) {
        fprintf(stderr,
                "the first stop's location was not honoured: the run from the "
                "axis start to its midpoint should hold the first stop\n");
        status = 7;
    }
    if (!near(end.r, 0, 30) || !near(end.b, 255, 30)) {
        fprintf(stderr, "the axis did not reach the second stop at its end\n");
        status = 7;
    }

    CGContextRelease(context);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    return status;
}

/* 8: radial falloff depends on the distance from the centre. */
static int testRadial(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 1.0, 0.0, 0.0, 1.0, /* opaque red at the centre */
                             0.0, 0.0, 1.0, 1.0 }; /* opaque blue at the edge */
    CGFloat locations[] = { 0.0, 1.0 };
    CGGradientRef gradient =
            CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextRef context;
    Pixel centre, inner, outer, corner;
    int status = 0;
    int variation;

    if (gradient == NULL)
        return 1;

    context = createContext();
    if (context == NULL) {
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        return 1;
    }

    /* Two circles of different radius, so the falloff has to be read from the
     * colour rather than from the geometry. */
    CGContextDrawRadialGradient(context, gradient, CGPointMake(16, 16), 0.0,
                                CGPointMake(16, 16), 14.0, 0);
    centre = pixelAt(context, 16, 16);
    inner = pixelAt(context, 16, 23);
    outer = pixelAt(context, 16, 29);
    report("radial: centre", centre);
    report("radial: inner", inner);
    report("radial: outer", outer);

    /* The sampled pixels are up to half a pixel off the exact centre and the
     * exact end radius, so the falloff is checked as an ordering: the first
     * channel falls and the last rises with distance. */
    if (!(centre.r > inner.r && inner.r > outer.r)) {
        fprintf(stderr,
                "the radial gradient does not fall off with distance: r=%u, "
                "r=%u, r=%u\n",
                centre.r, inner.r, outer.r);
        status = 8;
    }
    if (!(centre.b < inner.b && inner.b < outer.b)) {
        fprintf(stderr, "the radial gradient's last channel does not rise "
                        "with distance: b=%u, b=%u, b=%u\n",
                centre.b, inner.b, outer.b);
        status = 8;
    }
    if (!(centre.r > centre.b && outer.b > outer.r)) {
        fprintf(stderr, "the radial gradient did not reach both of its stops\n");
        status = 8;
    }

    /* Beyond the end radius nothing is painted without the extend option, so the
     * corner keeps the cleared value. */
    corner = pixelAt(context, 2, 2);
    report("radial: corner", corner);
    if (corner.a != 0) {
        fprintf(stderr, "the radial gradient painted beyond its end radius "
                        "without kCGGradientDrawsAfterEndLocation\n");
        status = 8;
    }

    variation = distinctColoursAcrossRow(context, HEIGHT - 1 - 16, 2, 29);
    if (variation < 8) {
        fprintf(stderr,
                "a radial gradient along a row produced %d distinct colours, "
                "so the row is a flat fill\n",
                variation);
        status = 8;
    }

    CGContextRelease(context);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    return status;
}

/* 9: the drawing options decide whether the gradient paints outside its axis. */
static int testExtendOptions(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0 };
    CGFloat locations[] = { 0.0, 1.0 };
    CGGradientRef gradient =
            CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextRef context;
    Pixel beyond, extended;
    int status = 0;

    if (gradient == NULL)
        return 1;

    /* A short axis in the middle of an otherwise empty context: the pixels to
     * the left and right of it are only painted if the options extend the
     * gradient there. */
    context = createContext();
    if (context == NULL) {
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        return 1;
    }
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(16.5, HEIGHT / 2),
                                CGPointMake(48.5, HEIGHT / 2), 0);
    beyond = pixelAt(context, 2, HEIGHT - 1 - (HEIGHT / 2));
    if (beyond.a != 0) {
        fprintf(stderr, "a linear gradient painted before its start location "
                        "without kCGGradientDrawsBeforeStartLocation\n");
        status = 9;
    }
    CGContextRelease(context);

    context = createContext();
    if (context == NULL) {
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        return 9;
    }
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(16.5, HEIGHT / 2),
                                CGPointMake(48.5, HEIGHT / 2),
                                kCGGradientDrawsBeforeStartLocation |
                                        kCGGradientDrawsAfterEndLocation);
    extended = pixelAt(context, 2, HEIGHT - 1 - (HEIGHT / 2));
    report("extend: before start", extended);
    if (extended.a == 0) {
        fprintf(stderr, "kCGGradientDrawsBeforeStartLocation did not paint "
                        "before the start location\n");
        status = 9;
    }
    extended = pixelAt(context, 60, HEIGHT - 1 - (HEIGHT / 2));
    report("extend: after end", extended);
    if (extended.a == 0) {
        fprintf(stderr, "kCGGradientDrawsAfterEndLocation did not paint after "
                        "the end location\n");
        status = 9;
    }
    CGContextRelease(context);

    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    return status;
}

/* 10: the gradient is limited to the current clip. */
static int testClip(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0 };
    CGFloat locations[] = { 0.0, 1.0 };
    CGGradientRef gradient =
            CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextRef context;
    Pixel inside, outside;
    int status = 0;

    if (gradient == NULL)
        return 1;

    context = createContext();
    if (context == NULL) {
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        return 1;
    }

    CGContextClipToRect(context, CGRectMake(0, 0, WIDTH / 2, HEIGHT));
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, HEIGHT / 2),
                                CGPointMake(WIDTH, HEIGHT / 2), 0);
    inside = pixelAt(context, 8, HEIGHT / 2);
    outside = pixelAt(context, WIDTH - 8, HEIGHT / 2);
    report("clip: inside", inside);
    report("clip: outside", outside);

    if (inside.a == 0) {
        fprintf(stderr, "the clipped region was not painted\n");
        status = 10;
    }
    if (outside.a != 0) {
        fprintf(stderr, "the gradient painted outside the current clip\n");
        status = 10;
    }

    CGContextRelease(context);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    return status;
}

/* The public accessors have to report what the gradient actually holds, and the
 * TypeID has to be a real, registered CF type: the drawing path and any client
 * that wants to store a gradient in a CF container both go through them. */
static int testAccessors(void) {
    static const CGFloat components[] = {
        1.0f, 0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f, 1.0f,
    };
    static const CGFloat locations[] = { 0.25f, 0.75f };
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient;
    const CGFloat *got;
    int status = 0;

    if (space == NULL) {
        fprintf(stderr, "accessors: no device RGB colour space\n");
        return 11;
    }

    if (CGGradientGetTypeID() == 0) {
        fprintf(stderr, "accessors: CGGradientGetTypeID returned 0\n");
        CGColorSpaceRelease(space);
        return 11;
    }

    gradient = CGGradientCreateWithColorComponents(space, components, locations, 2);
    if (gradient == NULL) {
        fprintf(stderr, "accessors: could not create a gradient\n");
        CGColorSpaceRelease(space);
        return 11;
    }

    if (CGGradientGetCount(gradient) != 2) {
        fprintf(stderr, "accessors: count is %zu, want 2\n",
                CGGradientGetCount(gradient));
        status = 11;
    }

    got = CGGradientGetLocations(gradient);
    if (got == NULL || got[0] != 0.25f || got[1] != 0.75f) {
        fprintf(stderr, "accessors: locations are %g,%g, want 0.25,0.75\n",
                got != NULL ? (double) got[0] : -1.0,
                got != NULL ? (double) got[1] : -1.0);
        status = 11;
    }

    got = CGGradientGetColors(gradient);
    if (got == NULL || got[0] != 1.0f || got[3] != 1.0f || got[4] != 0.0f ||
        got[6] != 1.0f) {
        fprintf(stderr, "accessors: components do not match what was passed in\n");
        status = 11;
    }

    if (CGGradientGetColorSpace(gradient) != space) {
        fprintf(stderr, "accessors: colour space is not the one the gradient "
                        "was created with\n");
        status = 11;
    }

    fprintf(stderr, "accessors: count %zu, locations %g,%g\n",
            CGGradientGetCount(gradient),
            (double) CGGradientGetLocations(gradient)[0],
            (double) CGGradientGetLocations(gradient)[1]);

    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    return status;
}


/* The accessors have to come from the library under test. A link with
 * -undefined suppress will happily leave one unresolved and turn it into a null
 * call, and the framework in the prefix predates the accessors, so merely linking
 * proves nothing. This resolves each one twice: from the library this run was
 * pointed at, and from the process itself, and requires both to be the same
 * non-null address. A symbol that came from the system framework, or that did not
 * resolve at all, fails here rather than in the pixel comparisons.
 */
static int testAccessorBinding(const char *library) {
    static const char *names[] = {
        "CGGradientGetTypeID", "CGGradientGetCount", "CGGradientGetLocations",
        "CGGradientGetColors", "CGGradientGetColorSpace",
    };
    void *handle;
    size_t i;
    int status = 0;

    if (library == NULL) {
        fprintf(stderr, "binding: no library given; pass the built gradient "
                        "library as the first argument\n");
        return 12;
    }

    handle = dlopen(library, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        fprintf(stderr, "binding: could not load %s: %s\n", library, dlerror());
        return 12;
    }

    for (i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        void *fromLibrary = dlsym(handle, names[i]);
        void *fromProcess = dlsym(RTLD_DEFAULT, names[i]);

        if (fromLibrary == NULL) {
            fprintf(stderr, "binding: %s is not in %s\n", names[i], library);
            status = 12;
            continue;
        }
        if (fromProcess == NULL) {
            fprintf(stderr, "binding: %s does not resolve in the process\n",
                    names[i]);
            status = 12;
            continue;
        }
        if (fromLibrary != fromProcess) {
            fprintf(stderr, "binding: %s resolves to %p in the library but %p "
                            "in the process, so the library under test is not "
                            "the one being used\n",
                    names[i], fromLibrary, fromProcess);
            status = 12;
            continue;
        }
    }

    dlclose(handle);
    return status;
}

int main(int argc, char **argv) {
    int status = 0;
    int failed = 0;

    struct {
        const char *name;
        int (*run)(void);
        int code;
    } tests[] = {
        { "components", testComponents, 2 },
        { "colors", testColors, 3 },
        { "linear interpolation", testLinearInterpolation, 5 },
        { "locations", testLocations, 7 },
        { "radial falloff", testRadial, 8 },
        { "extend options", testExtendOptions, 9 },
        { "clip", testClip, 10 },
        { "accessors", testAccessors, 11 },
    };
    size_t i;

    /* Resolving the accessors is the precondition for the rest: if the library
     * under test is not the one in use, every colour comparison below would be
     * reading somebody else's CoreGraphics. */
    {
        int bound = testAccessorBinding(argc > 1 ? argv[1] : NULL);
        if (bound != 0) {
            fprintf(stderr, "FAIL accessors are not bound to the library under "
                            "test (code %d)\n", bound);
            return bound;
        }
        fprintf(stderr, "ok   accessors bound to the library under test\n");
    }

    for (i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        int result = tests[i].run();
        if (result != 0) {
            fprintf(stderr, "FAIL %s (code %d)\n", tests[i].name, result);
            failed++;
            if (status == 0)
                status = tests[i].code;
        } else {
            fprintf(stderr, "ok   %s\n", tests[i].name);
        }
    }

    if (failed != 0)
        fprintf(stderr, "%d gradient test(s) failed\n", failed);
    else
        fprintf(stderr, "all gradient tests passed\n");
    return status;
}
