/*
 * CAShapeLayer gradient regression.
 *
 * A shape layer has one fill colour, so a gradient has to be a property of the
 * layer rather than something the fill can express. The checks below are written
 * as invariants rather than as absolute channel values, because the pixels come
 * out of a layer's private bitmap whose channel order is the context's business,
 * not the caller's:
 *
 *   - with a gradient set, the fill colour no longer paints;
 *   - the two ends of the axis differ, so it is not one flat colour;
 *   - every channel varies monotonically along the axis, which is what makes it a
 *     gradient rather than noise;
 *   - nothing is painted outside the path;
 *   - clearing the gradient brings fillColor back.
 *
 * Exit status is the number of failed checks.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>

#define WIDTH 64
#define HEIGHT 64

static int failures = 0;

static void expect(int condition, const char *what) {
	if (condition) {
		printf("ok   %s\n", what);
	} else {
		printf("FAIL %s\n", what);
		failures++;
	}
}

/* One pixel as four channel values, in whatever order the bitmap stores them. */
typedef struct { unsigned char c[4]; } Pixel;

static Pixel pixelAt(CGImageRef image, int x, int y) {
	Pixel out = {{0, 0, 0, 0}};
	if (image == NULL)
		return out;

	unsigned char buffer[4] = {0, 0, 0, 0};
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	/* A 1x1 context in the same pixel format, reading into a buffer we own. */
	CGContextRef scratch = CGBitmapContextCreate(buffer, 1, 1, 8, 4, space,
	                                             kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
	CGColorSpaceRelease(space);
	if (scratch == NULL)
		return out;

	CGImageRef one = CGImageCreateWithImageInRect(image, CGRectMake(x, y, 1, 1));
	if (one != NULL) {
		CGContextDrawImage(scratch, CGRectMake(0, 0, 1, 1), one);
		CGImageRelease(one);
	}
	CGContextRelease(scratch);

	out.c[0] = buffer[0];
	out.c[1] = buffer[1];
	out.c[2] = buffer[2];
	out.c[3] = buffer[3];
	return out;
}

static int equal(Pixel a, Pixel b) {
	return a.c[0] == b.c[0] && a.c[1] == b.c[1] && a.c[2] == b.c[2] && a.c[3] == b.c[3];
}

/* True when every channel moves in one direction only, or not at all. */
static int monotonic(const Pixel *row, int count) {
	for (int ch = 0; ch < 4; ch++) {
		int rising = 0, falling = 0;
		for (int i = 1; i < count; i++) {
			if (row[i].c[ch] > row[i - 1].c[ch])
				rising = 1;
			else if (row[i].c[ch] < row[i - 1].c[ch])
				falling = 1;
		}
		if (rising && falling)
			return 0;
	}
	return 1;
}

static CGColorRef solidColor(CGFloat r, CGFloat g, CGFloat b) {
	CGFloat components[] = {r, g, b, 1};
	return CGColorCreate(CGColorSpaceCreateDeviceRGB(), components);
}

int main(void) {
	CGRect bounds = CGRectMake(0, 0, WIDTH, HEIGHT);
	static const CGFloat stops[] = {1, 0, 0, 1, 0, 0, 1, 1};  /* red, then blue */
	static const CGFloat places[] = {0, 1};

	CGGradientRef gradient = CGGradientCreateWithColorComponents(
	        CGColorSpaceCreateDeviceRGB(), stops, places, 2);
	if (gradient == NULL) {
		printf("FAIL could not create the gradient\n");
		return 1;
	}

	/* What the layer looks like with only the flat fill, for comparison. */
	CAShapeLayer *plain = [[CAShapeLayer alloc] init];
	[plain setFrame: bounds];
	[plain setPath: CGPathCreateWithRect(bounds, NULL)];
	[plain setFillColor: solidColor(0, 1, 0)];
	[plain display];
	Pixel flatMiddle = pixelAt((CGImageRef)[plain contents], WIDTH / 2, HEIGHT / 2);

	CAShapeLayer *layer = [[CAShapeLayer alloc] init];
	[layer setFrame: bounds];
	[layer setPath: CGPathCreateWithRect(bounds, NULL)];
	[layer setFillColor: solidColor(0, 1, 0)];  /* must lose to the gradient */
	[layer setGradient: gradient];
	[layer setStartPoint: CGPointMake(0, 0)];
	[layer setEndPoint: CGPointMake(WIDTH, 0)];
	[layer display];

	CGImageRef rendered = (CGImageRef)[layer contents];
	expect(rendered != NULL, "the layer rendered contents");
	if (rendered == NULL)
		return 1;

	Pixel row[5];
	for (int i = 0; i < 5; i++)
		row[i] = pixelAt(rendered, 4 + i * 14, HEIGHT / 2);

	expect(!equal(row[2], flatMiddle), "the gradient replaced fillColor");
	expect(!equal(row[0], row[4]), "the two ends of the axis differ, so it is not a flat fill");
	expect(monotonic(row, 5), "every channel varies monotonically along the axis");

	/* Nothing is painted outside the path. */
	CAShapeLayer *clipped = [[CAShapeLayer alloc] init];
	[clipped setFrame: bounds];
	[clipped setPath: CGPathCreateWithRect(CGRectMake(0, 0, WIDTH, HEIGHT / 2), NULL)];
	[clipped setGradient: gradient];
	[clipped display];
	Pixel inside = pixelAt((CGImageRef)[clipped contents], WIDTH / 2, HEIGHT / 4);
	Pixel outside = pixelAt((CGImageRef)[clipped contents], WIDTH / 2, HEIGHT - 2);
	expect(!equal(inside, outside), "the gradient is clipped to the path");

	/* Clearing the gradient brings the flat fill back. */
	[layer setGradient: NULL];
	[layer display];
	Pixel restored = pixelAt((CGImageRef)[layer contents], WIDTH / 2, HEIGHT / 2);
	expect(equal(restored, flatMiddle), "with no gradient the fill colour is used again");

	printf(failures == 0 ? "PASS\n" : "FAILURES %d\n", failures);
	return failures == 0 ? 0 : 1;
}
