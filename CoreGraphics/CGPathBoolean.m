/* CGPath boolean operations: union, intersection, subtraction, symmetric
   difference, normalizing, line clipping, component separation and an overlap
   test.

   Apple's documentation for these functions says nothing about their results,
   so everything not stated there is a GUESS marked as such. The polygon
   algorithm lives in src/CGPathBoolean.c; this file turns paths into polygons
   and polygons back into paths. */

#import "CGConversions.h"
#import <CoreFoundation/CFArray.h>
#import <CoreGraphics/CGPath.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "src/CGPathBoolean.h"

/* GUESS (not in the public documentation, not observed): curves are flattened
   to line segments before the operation, so the result of any boolean
   operation is made of straight segments only. A real Mac probably keeps
   curves. The flatness is 1/8192 of the larger side of the box around both
   inputs' control points, and one curve never becomes more than 1000 segments. */
#define FLATNESS_DIVISOR 8192.0
#define MAX_SEGMENTS_PER_CURVE 1000

typedef struct {
    size_t first, count;
    bool closed;
} FlatSpan;

typedef struct {
    CGPBPoint *points;
    size_t npoints, pointCap;
    FlatSpan *spans;
    size_t nspans, spanCap;
    CGPBContour *contours;
    double tolerance;
    CGPoint start, current;
    bool open; /* a span is being built */
    bool oom;
} Flattened;

static void flat_point(Flattened *f, CGPoint p)
{
    if (f->oom)
        return;
    if (f->npoints == f->pointCap) {
        size_t cap = f->pointCap ? f->pointCap * 2 : 64;
        CGPBPoint *grown = realloc(f->points, cap * sizeof(CGPBPoint));
        if (grown == NULL) {
            f->oom = true;
            return;
        }
        f->points = grown;
        f->pointCap = cap;
    }
    f->points[f->npoints].x = p.x;
    f->points[f->npoints].y = p.y;
    f->npoints++;
    f->spans[f->nspans - 1].count++;
}

static void flat_begin(Flattened *f, CGPoint p)
{
    if (f->oom)
        return;
    if (f->nspans == f->spanCap) {
        size_t cap = f->spanCap ? f->spanCap * 2 : 8;
        FlatSpan *grown = realloc(f->spans, cap * sizeof(FlatSpan));
        if (grown == NULL) {
            f->oom = true;
            return;
        }
        f->spans = grown;
        f->spanCap = cap;
    }
    f->spans[f->nspans].first = f->npoints;
    f->spans[f->nspans].count = 0;
    f->spans[f->nspans].closed = false;
    f->nspans++;
    f->open = true;
    f->start = f->current = p;
    flat_point(f, p);
}

static size_t curve_segments(double bend, double coefficient, double tolerance)
{
    if (!(bend > 0) || !isfinite(bend))
        return 1;
    double n = ceil(sqrt(coefficient * bend / tolerance));
    if (!(n >= 1))
        return 1;
    return n > MAX_SEGMENTS_PER_CURVE ? MAX_SEGMENTS_PER_CURVE : (size_t) n;
}

static double bend_of(CGPoint a, CGPoint b, CGPoint c)
{
    return hypot(a.x - 2 * b.x + c.x, a.y - 2 * b.y + c.y);
}

static void flat_apply(void *info, const CGPathElement *element)
{
    Flattened *f = info;
    const CGPoint *p = element->points;
    switch (element->type) {
    case kCGPathElementMoveToPoint:
        flat_begin(f, p[0]);
        break;
    case kCGPathElementAddLineToPoint:
        if (!f->open)
            flat_begin(f, f->current);
        flat_point(f, p[0]);
        f->current = p[0];
        break;
    case kCGPathElementAddQuadCurveToPoint: {
        if (!f->open)
            flat_begin(f, f->current);
        CGPoint p0 = f->current;
        size_t n = curve_segments(bend_of(p0, p[0], p[1]), 0.25, f->tolerance);
        for (size_t i = 1; i <= n; i++) {
            double t = (double) i / n, u = 1 - t;
            CGPoint q = i == n ? p[1]
                               : CGPointMake(u * u * p0.x + 2 * u * t * p[0].x + t * t * p[1].x,
                                             u * u * p0.y + 2 * u * t * p[0].y + t * t * p[1].y);
            flat_point(f, q);
        }
        f->current = p[1];
        break;
    }
    case kCGPathElementAddCurveToPoint: {
        if (!f->open)
            flat_begin(f, f->current);
        CGPoint p0 = f->current;
        double bend = fmax(bend_of(p0, p[0], p[1]), bend_of(p[0], p[1], p[2]));
        size_t n = curve_segments(bend, 0.75, f->tolerance);
        for (size_t i = 1; i <= n; i++) {
            double t = (double) i / n, u = 1 - t;
            double a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
            CGPoint q = i == n ? p[2]
                               : CGPointMake(a * p0.x + b * p[0].x + c * p[1].x + d * p[2].x,
                                             a * p0.y + b * p[0].y + c * p[1].y + d * p[2].y);
            flat_point(f, q);
        }
        f->current = p[2];
        break;
    }
    case kCGPathElementCloseSubpath:
        if (f->open) {
            f->spans[f->nspans - 1].closed = true;
            f->open = false;
            f->current = f->start;
        }
        break;
    }
}

static void flat_extent_apply(void *info, const CGPathElement *element)
{
    CGRect *box = info;
    int n = element->type == kCGPathElementCloseSubpath ? 0
            : element->type == kCGPathElementAddCurveToPoint ? 3
            : element->type == kCGPathElementAddQuadCurveToPoint ? 2 : 1;
    for (int i = 0; i < n; i++)
        *box = CGRectUnion(*box, CGRectMake(element->points[i].x, element->points[i].y, 0, 0));
}

static void flat_free(Flattened *f)
{
    free(f->points);
    free(f->spans);
    free(f->contours);
}

/* Flatten a path with a fixed tolerance. Contours point into f->points, which
   is final once flattening ends, so they are built afterwards. */
static bool flat_build(Flattened *f, CGPathRef path, double tolerance)
{
    memset(f, 0, sizeof *f);
    f->tolerance = tolerance;
    CGPathApply(path, f, flat_apply);
    if (f->oom)
        return false;
    if (f->nspans > 0) {
        f->contours = malloc(f->nspans * sizeof(CGPBContour));
        if (f->contours == NULL)
            return false;
        for (size_t i = 0; i < f->nspans; i++) {
            f->contours[i].points = f->points + f->spans[i].first;
            f->contours[i].count = f->spans[i].count;
            f->contours[i].closed = f->spans[i].closed;
        }
    }
    return true;
}

static double tolerance_for(CGPathRef a, CGPathRef b)
{
    CGRect box = CGRectNull;
    CGPathApply(a, &box, flat_extent_apply);
    if (b != NULL)
        CGPathApply(b, &box, flat_extent_apply);
    if (CGRectIsNull(box))
        return 1;
    double extent = fmax(box.size.width, box.size.height) / FLATNESS_DIVISOR;
    return extent > 0 && isfinite(extent) ? extent : 1;
}

static CGPathRef path_from_result(const CGPBResult *result, size_t group, bool all)
{
    CGMutablePathRef path = CGPathCreateMutable();
    for (size_t i = 0; i < result->count; i++) {
        const CGPBRing *ring = &result->rings[i];
        if (!all && ring->group != group)
            continue;
        CGPathMoveToPoint(path, NULL, ring->points[0].x, ring->points[0].y);
        for (size_t k = 1; k < ring->count; k++)
            CGPathAddLineToPoint(path, NULL, ring->points[k].x, ring->points[k].y);
        if (ring->closed)
            CGPathCloseSubpath(path);
    }
    return (CGPathRef) path;
}

static const char *status_text(CGPBStatus st)
{
    switch (st) {
    case CGPBStatusNoMemory: return "out of memory";
    case CGPBStatusNonFinite: return "a coordinate is NaN or infinite";
    case CGPBStatusTooLarge: return "the coordinates span more than a double can hold";
    case CGPBStatusInconsistent: return "the paths are degenerate beyond what the algorithm handles";
    default: return "unknown error";
    }
}

/* Run `run` on the flattened inputs; NULL (with a message on stderr) when the
   inputs are unusable. `other` may be NULL for single-path operations. */
typedef CGPBStatus (*PathRun)(const CGPBContour *a, size_t na, const CGPBContour *b, size_t nb,
                              void *arg, CGPBResult *result);

static bool run_on_paths(const char *name, CGPathRef path, CGPathRef other, PathRun run,
                         void *arg, CGPBResult *result)
{
    Flattened fa, fb;
    double tol = tolerance_for(path, other);
    memset(&fb, 0, sizeof fb);
    if (!flat_build(&fa, path, tol) || (other != NULL && !flat_build(&fb, other, tol))) {
        fprintf(stderr, "%s: out of memory\n", name);
        flat_free(&fa);
        flat_free(&fb);
        return false;
    }
    CGPBStatus st = run(fa.contours, fa.nspans, fb.contours, fb.nspans, arg, result);
    flat_free(&fa);
    flat_free(&fb);
    if (st != CGPBStatusOK) {
        fprintf(stderr, "%s: %s\n", name, status_text(st));
        return false;
    }
    return true;
}

typedef struct {
    CGPBOp op;
    bool evenOdd, groups;
} RegionArg;

static CGPBStatus run_region(const CGPBContour *a, size_t na, const CGPBContour *b, size_t nb,
                             void *arg, CGPBResult *result)
{
    const RegionArg *r = arg;
    return CGPBRegion(r->op, a, na, b, nb, r->evenOdd, r->groups, result);
}

/* GUESS (not in the public documentation, not observed): a NULL path or mask
   returns NULL, as does an input with a NaN or infinite coordinate (after a
   message on stderr). An empty result is an empty path, not NULL. */
static CGPathRef region_operation(const char *name, CGPathRef path, CGPathRef mask, CGPBOp op,
                                  bool evenOdd)
{
    if (path == NULL || (op != CGPBOpNormalize && mask == NULL))
        return NULL;
    RegionArg arg = {op, evenOdd, false};
    CGPBResult result;
    if (!run_on_paths(name, path, op == CGPBOpNormalize ? NULL : mask, run_region, &arg, &result))
        return NULL;
    CGPathRef out = path_from_result(&result, 0, true);
    CGPBResultFree(&result);
    return out;
}

CGPathRef CGPathCreateCopyByUnioningPath(CGPathRef path, CGPathRef maskPath, bool evenOddFillRule)
{
    return region_operation("CGPathCreateCopyByUnioningPath", path, maskPath, CGPBOpUnion,
                            evenOddFillRule);
}

CGPathRef CGPathCreateCopyByIntersectingPath(CGPathRef path, CGPathRef maskPath,
                                             bool evenOddFillRule)
{
    return region_operation("CGPathCreateCopyByIntersectingPath", path, maskPath,
                            CGPBOpIntersection, evenOddFillRule);
}

CGPathRef CGPathCreateCopyBySubtractingPath(CGPathRef path, CGPathRef maskPath,
                                            bool evenOddFillRule)
{
    return region_operation("CGPathCreateCopyBySubtractingPath", path, maskPath,
                            CGPBOpSubtraction, evenOddFillRule);
}

CGPathRef CGPathCreateCopyBySymmetricallyDifferencingPath(CGPathRef path, CGPathRef maskPath,
                                                          bool evenOddFillRule)
{
    return region_operation("CGPathCreateCopyBySymmetricallyDifferencingPath", path, maskPath,
                            CGPBOpSymmetricDifference, evenOddFillRule);
}

CGPathRef CGPathCreateCopyByNormalizing(CGPathRef path, bool evenOddFillRule)
{
    return region_operation("CGPathCreateCopyByNormalizing", path, NULL, CGPBOpNormalize,
                            evenOddFillRule);
}
