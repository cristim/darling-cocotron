#include <CoreGraphics/CoreGraphics.h>

static void countElements(void *context, const CGPathElement *element) {
    unsigned *counts = context;
    counts[element->type]++;
}

int main(void) {
    CGRect rect = CGRectMake(10, 20, 80, 40);
    CGPathRef path = CGPathCreateWithRoundedRect(rect, 12, 6, NULL);
    if (path == NULL)
        return 1;

    unsigned counts[5] = {0};
    CGPathApply(path, counts, countElements);
    if (counts[kCGPathElementMoveToPoint] != 1 ||
        counts[kCGPathElementAddCurveToPoint] != 4 ||
        counts[kCGPathElementCloseSubpath] != 1)
        return 2;
    if (!CGRectEqualToRect(CGPathGetBoundingBox(path), rect))
        return 3;
    if (!CGPathContainsPoint(path, NULL, CGPointMake(50, 40), false) ||
        CGPathContainsPoint(path, NULL, CGPointMake(10, 20), false))
        return 4;
    CGPathRelease(path);

    CGAffineTransform translation = CGAffineTransformMakeTranslation(3, 5);
    path = CGPathCreateWithRoundedRect(rect, 12, 6, &translation);
    if (!CGRectEqualToRect(CGPathGetBoundingBox(path),
                           CGRectMake(13, 25, 80, 40)))
        return 5;
    CGPathRelease(path);

    CGMutablePathRef mutable = CGPathCreateMutable();
    CGPathAddRoundedRect(mutable, NULL, rect, 0, 0);
    CGRect detected;
    if (!CGPathIsRect(mutable, &detected) || !CGRectEqualToRect(detected, rect))
        return 6;
    CGPathRelease(mutable);
    return 0;
}
