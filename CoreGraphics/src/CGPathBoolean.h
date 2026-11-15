#ifndef CGPATHBOOLEAN_H
#define CGPATHBOOLEAN_H

/* Boolean operations on polygon sets (internal to CoreGraphics).

   Written from scratch for Darling's Cocotron CoreGraphics. The method is the
   textbook one: snap every vertex to an integer grid, node the segments by
   snap rounding (Hobby 1999; Guibas and Marimont 1998), label each noded edge
   with the winding number on both of its sides, and keep the edges where the
   chosen operation changes between inside and outside. Everything after the
   snapping is exact integer arithmetic. No third-party code is used. */

#include <stdbool.h>
#include <stddef.h>

typedef struct {
    double x, y;
} CGPBPoint;

/* One input subpath, already flattened to line segments. Every contour is
   treated as closed (a fill closes open subpaths); `closed` is not read. */
typedef struct {
    const CGPBPoint *points;
    size_t count;
    bool closed;
} CGPBContour;

typedef struct {
    CGPBPoint *points;
    size_t count;
    bool closed;
    bool hole;    /* region results: clockwise ring bounding a hole */
    size_t group; /* region results: index of the component the ring belongs to */
} CGPBRing;

typedef struct {
    CGPBRing *rings;
    size_t count;
} CGPBResult;

typedef enum {
    CGPBOpUnion,
    CGPBOpIntersection,
    CGPBOpSubtraction,        /* a minus b */
    CGPBOpSymmetricDifference,
    CGPBOpNormalize,          /* a alone, b ignored */
} CGPBOp;

typedef enum {
    CGPBStatusOK = 0,
    CGPBStatusNoMemory,
    CGPBStatusNonFinite,    /* a coordinate is NaN or infinite */
    CGPBStatusTooLarge,     /* the coordinate range overflows a double */
    CGPBStatusInconsistent, /* the noded graph is not a planar subdivision */
    CGPBStatusTooComplex,   /* more crossings or work than the fixed limits allow */
} CGPBStatus;

/* Region operations. The result is a set of closed rings: outer rings run
   counter-clockwise, holes clockwise, no two rings cross, so the result fills
   the same under either fill rule. Empty regions give zero rings. With
   wantGroups each ring's `group` names its component: an outer ring and the
   holes directly inside it (an island inside a hole starts its own). */
CGPBStatus CGPBRegion(CGPBOp op, const CGPBContour *a, size_t na,
                      const CGPBContour *b, size_t nb, bool evenOdd,
                      bool wantGroups, CGPBResult *result);

void CGPBResultFree(CGPBResult *result);

#endif
