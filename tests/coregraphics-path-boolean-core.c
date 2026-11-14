/* Host-side test of the polygon boolean core behind the CGPath boolean
   operations (CoreGraphics/src/CGPathBoolean.c). Plain C, no CoreGraphics:

     cc -std=gnu11 -O2 -I CoreGraphics/src tests/coregraphics-path-boolean-core.c \
        CoreGraphics/src/CGPathBoolean*.c -lm

   Random polygons (self-intersecting, on tiny integer grids so edges overlap
   and vertices coincide, and with float coordinates at several scales) are run
   through every operation and both fill rules. Each result is compared with a
   brute-force oracle: at sample points away from every input edge, inside the
   result must equal the boolean combination of inside-A and inside-B. The
   result's own structure is checked too: no crossing edges, the same answer
   under both fill rules, hole flags matching the ring orientation. */

#include "CGPathBoolean.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;
#define EXPECT(cond, ...)                                                      \
    do {                                                                       \
        if (!(cond)) {                                                         \
            failures++;                                                        \
            if (failures < 30) {                                               \
                fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__);           \
                fprintf(stderr, __VA_ARGS__);                                  \
                fputc('\n', stderr);                                           \
            }                                                                  \
        }                                                                      \
    } while (0)

static uint64_t rng_state = 88172645463325252ull;
static uint64_t rnd(void)
{
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 7;
    rng_state ^= rng_state << 17;
    return rng_state;
}
static double rndf(void) { return (double) (rnd() >> 11) / 9007199254740992.0; }
static int rndi(int n) { return (int) (rnd() % (uint64_t) n); }

/* ---- oracle ------------------------------------------------------------- */

static int winding_at(const CGPBContour *cs, size_t nc, double px, double py)
{
    int w = 0;
    for (size_t c = 0; c < nc; c++) {
        size_t n = cs[c].count;
        for (size_t i = 0; i < n; i++) {
            CGPBPoint a = cs[c].points[i], b = cs[c].points[(i + 1) % n];
            if ((a.y <= py) == (b.y <= py))
                continue;
            double cr = (b.x - a.x) * (py - a.y) - (b.y - a.y) * (px - a.x);
            if (b.y > a.y && cr > 0)
                w++;
            else if (b.y < a.y && cr < 0)
                w--;
        }
    }
    return w;
}

static bool inside(const CGPBContour *cs, size_t nc, double px, double py, bool eo)
{
    int w = winding_at(cs, nc, px, py);
    return eo ? (w & 1) != 0 : w != 0;
}

static double dist_seg(double px, double py, CGPBPoint a, CGPBPoint b)
{
    double dx = b.x - a.x, dy = b.y - a.y, l2 = dx * dx + dy * dy;
    double t = l2 > 0 ? ((px - a.x) * dx + (py - a.y) * dy) / l2 : 0;
    t = t < 0 ? 0 : t > 1 ? 1 : t;
    double ex = a.x + t * dx - px, ey = a.y + t * dy - py;
    return sqrt(ex * ex + ey * ey);
}

static double dist_contours(const CGPBContour *cs, size_t nc, double px, double py,
                            bool closeAll)
{
    double best = INFINITY;
    for (size_t c = 0; c < nc; c++) {
        size_t n = cs[c].count;
        size_t segs = (closeAll || cs[c].closed) ? n : (n ? n - 1 : 0);
        if (n == 1)
            best = fmin(best, hypot(px - cs[c].points[0].x, py - cs[c].points[0].y));
        for (size_t i = 0; i < segs; i++)
            best = fmin(best, dist_seg(px, py, cs[c].points[i], cs[c].points[(i + 1) % n]));
    }
    return best;
}

static double dist_result(const CGPBResult *r, double px, double py)
{
    double best = INFINITY;
    for (size_t c = 0; c < r->count; c++) {
        const CGPBRing *ring = &r->rings[c];
        size_t segs = ring->closed ? ring->count : ring->count - 1;
        for (size_t i = 0; i < segs; i++)
            best = fmin(best, dist_seg(px, py, ring->points[i], ring->points[(i + 1) % ring->count]));
    }
    return best;
}

static bool result_inside(const CGPBResult *r, double px, double py, bool eo)
{
    int w = 0;
    for (size_t c = 0; c < r->count; c++) {
        const CGPBRing *ring = &r->rings[c];
        size_t n = ring->count;
        for (size_t i = 0; i < n; i++) {
            CGPBPoint a = ring->points[i], b = ring->points[(i + 1) % n];
            if ((a.y <= py) == (b.y <= py))
                continue;
            double cr = (b.x - a.x) * (py - a.y) - (b.y - a.y) * (px - a.x);
            if (b.y > a.y && cr > 0)
                w++;
            else if (b.y < a.y && cr < 0)
                w--;
        }
    }
    return eo ? (w & 1) != 0 : w != 0;
}

static double ring_area(const CGPBRing *r)
{
    double a = 0, ox = r->points[0].x, oy = r->points[0].y;
    for (size_t i = 0; i < r->count; i++) {
        CGPBPoint p = r->points[i], q = r->points[(i + 1) % r->count];
        a += (p.x - ox) * (q.y - oy) - (q.x - ox) * (p.y - oy);
    }
    return a / 2;
}

static double result_area(const CGPBResult *r)
{
    double a = 0;
    for (size_t i = 0; i < r->count; i++)
        a += ring_area(&r->rings[i]);
    return a;
}

/* no two edges of the result cross properly */
static void check_no_crossings(const CGPBResult *r, double eps, const char *what)
{
    size_t total = 0;
    for (size_t c = 0; c < r->count; c++)
        total += r->rings[c].count;
    CGPBPoint *a = malloc(total * sizeof *a), *b = malloc(total * sizeof *b);
    size_t m = 0;
    for (size_t c = 0; c < r->count; c++)
        for (size_t i = 0; i < r->rings[c].count; i++) {
            a[m] = r->rings[c].points[i];
            b[m++] = r->rings[c].points[(i + 1) % r->rings[c].count];
        }
    for (size_t i = 0; i < m; i++)
        for (size_t j = i + 1; j < m; j++) {
            double d1 = (b[i].x - a[i].x) * (a[j].y - a[i].y) - (b[i].y - a[i].y) * (a[j].x - a[i].x);
            double d2 = (b[i].x - a[i].x) * (b[j].y - a[i].y) - (b[i].y - a[i].y) * (b[j].x - a[i].x);
            double d3 = (b[j].x - a[j].x) * (a[i].y - a[j].y) - (b[j].y - a[j].y) * (a[i].x - a[j].x);
            double d4 = (b[j].x - a[j].x) * (b[i].y - a[j].y) - (b[j].y - a[j].y) * (b[i].x - a[j].x);
            if (((d1 > eps && d2 < -eps) || (d1 < -eps && d2 > eps)) &&
                ((d3 > eps && d4 < -eps) || (d3 < -eps && d4 > eps)))
                EXPECT(0, "%s: result edges %zu and %zu cross", what, i, j);
        }
    free(a);
    free(b);
}

/* ---- random input ------------------------------------------------------- */

typedef struct {
    CGPBContour c[4];
    CGPBPoint *pts[4];
    size_t n;
} Shape;

static void shape_free(Shape *s)
{
    for (size_t i = 0; i < s->n; i++)
        free(s->pts[i]);
    s->n = 0;
}

/* mode 0: integer grid of size grid; mode 1: floats in [0,grid]; */
static void shape_random(Shape *s, int mode, int grid, double scale, double ox, double oy)
{
    s->n = 1 + rndi(3);
    for (size_t k = 0; k < s->n; k++) {
        size_t n = 3 + rndi(7);
        s->pts[k] = malloc(n * sizeof(CGPBPoint));
        for (size_t i = 0; i < n; i++) {
            double x = mode == 0 ? rndi(grid + 1) : rndf() * grid;
            double y = mode == 0 ? rndi(grid + 1) : rndf() * grid;
            s->pts[k][i].x = ox + x * scale;
            s->pts[k][i].y = oy + y * scale;
        }
        s->c[k].points = s->pts[k];
        s->c[k].count = n;
        s->c[k].closed = rndi(2);
    }
}

static void shape_dump(const char *name, const Shape *s)
{
    for (size_t i = 0; i < s->n; i++) {
        fprintf(stderr, "  %s[%zu] %s:", name, i, s->c[i].closed ? "closed" : "open");
        for (size_t k = 0; k < s->c[i].count; k++)
            fprintf(stderr, " (%.17g,%.17g)", s->c[i].points[k].x, s->c[i].points[k].y);
        fputc('\n', stderr);
    }
}

static const char *opname[] = {"union", "intersection", "subtraction", "xor", "normalize"};

static bool expected_in(CGPBOp op, bool a, bool b)
{
    switch (op) {
    case CGPBOpUnion: return a || b;
    case CGPBOpIntersection: return a && b;
    case CGPBOpSubtraction: return a && !b;
    case CGPBOpSymmetricDifference: return a != b;
    default: return a;
    }
}

static void check_region(const Shape *a, const Shape *b, CGPBOp op, bool eo, double scale,
                         double ox, double oy, int grid, const char *tag, long iter)
{
    CGPBResult r;
    CGPBStatus st = CGPBRegion(op, a->c, a->n, b->c, b->n, eo, true, &r);
    EXPECT(st == CGPBStatusOK, "%s iter %ld %s eo=%d: status %d", tag, iter, opname[op], eo, st);
    if (st != CGPBStatusOK)
        return;
    double eps = 1e-6 * scale;
    {
        char what[96];
        snprintf(what, sizeof what, "%s iter %ld %s eo=%d", tag, iter, opname[op], eo);
        check_no_crossings(&r, 1e-9 * scale * scale, what);
    }
    for (size_t i = 0; i < r.count; i++) {
        EXPECT(r.rings[i].closed && r.rings[i].count >= 3, "ring shape");
        EXPECT(fabs(ring_area(&r.rings[i])) < 1e-9 * scale * scale || r.rings[i].hole == (ring_area(&r.rings[i]) < 0), "%s iter %ld hole flag vs area", tag, iter);
        EXPECT(r.rings[i].group < r.count, "group index");
    }
    for (int k = 0; k < 120; k++) {
        double px = ox + (rndf() * (grid + 2) - 1) * scale, py = oy + (rndf() * (grid + 2) - 1) * scale;
        if (dist_contours(a->c, a->n, px, py, true) < eps || dist_contours(b->c, b->n, px, py, true) < eps)
            continue;
        bool want = expected_in(op, inside(a->c, a->n, px, py, eo), inside(b->c, b->n, px, py, eo));
        bool gotw = result_inside(&r, px, py, false), gote = result_inside(&r, px, py, true);
        EXPECT(gotw == want && gote == want,
               "%s iter %ld %s eo=%d: point (%.9g,%.9g) want %d got winding %d evenodd %d", tag, iter,
               opname[op], eo, px, py, want, gotw, gote);
    }
    CGPBResultFree(&r);
}

static void check_lines(const Shape *a, const Shape *b, bool keepInside, bool eo, double scale,
                        const char *tag, long iter)
{
    CGPBResult r;
    CGPBStatus st = CGPBLines(keepInside, a->c, a->n, b->c, b->n, eo, &r);
    EXPECT(st == CGPBStatusOK, "%s iter %ld lines: status %d", tag, iter, st);
    if (st != CGPBStatusOK)
        return;
    double eps = 1e-6 * scale;
    /* every result point lies on a line of a and on the right side of b */
    for (size_t c = 0; c < r.count; c++) {
        const CGPBRing *ring = &r.rings[c];
        size_t segs = ring->closed ? ring->count : ring->count - 1;
        for (size_t i = 0; i < segs; i++) {
            CGPBPoint p = ring->points[i], q = ring->points[(i + 1) % ring->count];
            double t = 0.17 + 0.66 * rndf();
            double px = p.x + (q.x - p.x) * t, py = p.y + (q.y - p.y) * t;
            EXPECT(dist_contours(a->c, a->n, px, py, false) < eps, "%s iter %ld: result off the lines", tag, iter);
            if (dist_contours(b->c, b->n, px, py, true) > eps)
                EXPECT(inside(b->c, b->n, px, py, eo) == keepInside,
                       "%s iter %ld lines keepInside=%d: kept piece on the wrong side", tag, iter, keepInside);
        }
    }
    /* every sampled point of a line that is clear of b's boundary is kept iff
       it is on the wanted side */
    for (size_t c = 0; c < a->n; c++) {
        size_t n = a->c[c].count;
        size_t segs = a->c[c].closed ? n : n - 1;
        for (int k = 0; k < 30; k++) {
            size_t i = (size_t) rndi((int) segs);
            CGPBPoint p = a->c[c].points[i], q = a->c[c].points[(i + 1) % n];
            if (p.x == q.x && p.y == q.y)
                continue; /* a zero-length line draws nothing (GUESS) */
            double t = rndf();
            double px = p.x + (q.x - p.x) * t, py = p.y + (q.y - p.y) * t;
            if (dist_contours(b->c, b->n, px, py, true) < eps)
                continue;
            bool want = inside(b->c, b->n, px, py, eo) == keepInside;
            bool got = dist_result(&r, px, py) < eps;
            EXPECT(want == got, "%s iter %ld lines keepInside=%d: line point (%.9g,%.9g) want %d got %d",
                   tag, iter, keepInside, px, py, want, got);
        }
    }
    CGPBResultFree(&r);
}

static void fuzz(const char *tag, int mode, int grid, double scale, double ox, double oy, long iters)
{
    for (long it = 0; it < iters; it++) {
        Shape a, b;
        shape_random(&a, mode, grid, scale, ox, oy);
        shape_random(&b, mode, grid, scale, ox, oy);
        int before = failures;
        for (int eo = 0; eo < 2; eo++) {
            for (CGPBOp op = CGPBOpUnion; op <= CGPBOpNormalize; op++)
                check_region(&a, &b, op, eo, scale, ox, oy, grid, tag, it);
            for (int keep = 0; keep < 2; keep++)
                check_lines(&a, &b, keep, eo, scale, tag, it);
        }
        if (failures > before && before == 0) {
            shape_dump("A", &a);
            shape_dump("B", &b);
        }
        shape_free(&a);
        shape_free(&b);
    }
}

/* ---- hand-computed fixtures ---------------------------------------------- */

static void rect(CGPBPoint *p, double x0, double y0, double x1, double y1)
{
    p[0] = (CGPBPoint) {x0, y0};
    p[1] = (CGPBPoint) {x1, y0};
    p[2] = (CGPBPoint) {x1, y1};
    p[3] = (CGPBPoint) {x0, y1};
}

static void fixtures(void)
{
    CGPBPoint ra[4], rb[4];
    rect(ra, 0, 0, 2, 2);
    rect(rb, 1, 1, 3, 3);
    CGPBContour a = {ra, 4, true}, b = {rb, 4, true};
    CGPBResult r;
    double expectArea[5] = {7, 1, 3, 6, 4};
    size_t expectRings[5] = {1, 1, 1, 2, 1};
    for (CGPBOp op = CGPBOpUnion; op <= CGPBOpNormalize; op++) {
        EXPECT(CGPBRegion(op, &a, 1, &b, 1, false, false, &r) == CGPBStatusOK, "fixture %s", opname[op]);
        EXPECT(fabs(result_area(&r) - expectArea[op]) < 1e-12, "fixture %s area %g want %g", opname[op],
               result_area(&r), expectArea[op]);
        EXPECT(r.count == expectRings[op], "fixture %s rings %zu want %zu", opname[op], r.count, expectRings[op]);
        CGPBResultFree(&r);
    }
    /* union of rectangles sharing an edge: one ring of 4 corners, exact input coordinates */
    rect(ra, 0, 0, 1, 1);
    rect(rb, 1, 0, 2, 1);
    EXPECT(CGPBRegion(CGPBOpUnion, &a, 1, &b, 1, false, false, &r) == CGPBStatusOK && r.count == 1 &&
               r.rings[0].count == 4 && fabs(result_area(&r) - 2) < 1e-15,
           "adjacent rectangles merge into one 4-corner ring");
    bool exact = true;
    for (size_t i = 0; r.count == 1 && i < 4; i++) {
        double x = r.rings[0].points[i].x, y = r.rings[0].points[i].y;
        exact &= (x == 0 || x == 2) && (y == 0 || y == 1);
    }
    EXPECT(exact, "corners are the input coordinates");
    CGPBResultFree(&r);
    /* hole: big minus small, even-odd nested squares */
    CGPBPoint big[4], small[4];
    rect(big, 0, 0, 10, 10);
    rect(small, 3, 3, 7, 7);
    CGPBContour cb = {big, 4, true}, cs = {small, 4, true};
    EXPECT(CGPBRegion(CGPBOpSubtraction, &cb, 1, &cs, 1, false, true, &r) == CGPBStatusOK && r.count == 2 &&
               fabs(result_area(&r) - 84) < 1e-12 && r.rings[0].hole != r.rings[1].hole &&
               r.rings[0].group == r.rings[1].group,
           "square minus inner square is a ring with one hole in one component");
    CGPBResultFree(&r);
    /* same-direction nested squares: winding fills the middle, even-odd makes a hole */
    CGPBContour both[2] = {cb, cs};
    EXPECT(CGPBRegion(CGPBOpNormalize, both, 2, NULL, 0, false, false, &r) == CGPBStatusOK && r.count == 1 &&
               fabs(result_area(&r) - 100) < 1e-12, "winding normalize of nested same-direction squares");
    CGPBResultFree(&r);
    EXPECT(CGPBRegion(CGPBOpNormalize, both, 2, NULL, 0, true, false, &r) == CGPBStatusOK && r.count == 2 &&
               fabs(result_area(&r) - 84) < 1e-12, "even-odd normalize of nested squares has a hole");
    CGPBResultFree(&r);
    /* island inside a hole is its own component */
    CGPBPoint island[4];
    rect(island, 4, 4, 6, 6);
    CGPBContour three[3] = {cb, cs, {island, 4, true}};
    EXPECT(CGPBRegion(CGPBOpNormalize, three, 3, NULL, 0, true, true, &r) == CGPBStatusOK && r.count == 3,
           "island, hole and outer");
    size_t groups[3] = {r.rings[0].group, r.rings[1].group, r.rings[2].group};
    size_t distinct = 1 + (groups[1] != groups[0]) + (groups[2] != groups[0] && groups[2] != groups[1]);
    EXPECT(distinct == 2, "island forms its own component (got %zu groups)", distinct);
    CGPBResultFree(&r);
    /* a hole inside an island inside a hole: it belongs to the island, not to the outer frame */
    CGPBPoint f1[4], f2[4], f3[4], f4[4];
    rect(f1, 0, 0, 30, 30);
    rect(f2, 5, 5, 25, 25);
    rect(f3, 10, 10, 20, 20);
    rect(f4, 13, 13, 17, 17);
    CGPBContour four[4] = {{f1, 4, true}, {f2, 4, true}, {f3, 4, true}, {f4, 4, true}};
    EXPECT(CGPBRegion(CGPBOpNormalize, four, 4, NULL, 0, true, true, &r) == CGPBStatusOK && r.count == 4,
           "four nested squares give four rings");
    size_t outerGroup[2] = {0, 0}, holeGroup[2] = {0, 0};
    for (size_t k = 0; k < r.count; k++) {
        double area = fabs(ring_area(&r.rings[k]));
        if (!r.rings[k].hole) {
            outerGroup[area > 500 ? 0 : 1] = r.rings[k].group;
        } else {
            holeGroup[area > 300 ? 0 : 1] = r.rings[k].group;
        }
    }
    EXPECT(holeGroup[0] == outerGroup[0] && holeGroup[1] == outerGroup[1] && outerGroup[0] != outerGroup[1],
           "each hole joins the smallest outer ring around it");
    CGPBResultFree(&r);
    /* touching rectangles (corner only): union keeps two rings, intersection is empty */
    rect(ra, 0, 0, 1, 1);
    rect(rb, 1, 1, 2, 2);
    EXPECT(CGPBRegion(CGPBOpIntersection, &a, 1, &b, 1, false, false, &r) == CGPBStatusOK && r.count == 0,
           "corner-touching rectangles do not intersect");
    CGPBResultFree(&r);
    EXPECT(CGPBRegion(CGPBOpUnion, &a, 1, &b, 1, false, false, &r) == CGPBStatusOK && r.count == 2 &&
               fabs(result_area(&r) - 2) < 1e-15, "corner-touching union has two rings");
    CGPBResultFree(&r);
    /* identical inputs */
    rect(ra, 0, 0, 5, 5);
    rect(rb, 0, 0, 5, 5);
    EXPECT(CGPBRegion(CGPBOpSubtraction, &a, 1, &b, 1, false, false, &r) == CGPBStatusOK && r.count == 0,
           "a minus a is empty");
    CGPBResultFree(&r);
    EXPECT(CGPBRegion(CGPBOpIntersection, &a, 1, &b, 1, false, false, &r) == CGPBStatusOK && r.count == 1 &&
               fabs(result_area(&r) - 25) < 1e-12, "a and a is a");
    CGPBResultFree(&r);
    /* empty and degenerate inputs */
    CGPBPoint line2[2] = {{0, 0}, {5, 5}}, dot[1] = {{1, 1}};
    CGPBContour deg[2] = {{line2, 2, true}, {dot, 1, true}};
    EXPECT(CGPBRegion(CGPBOpUnion, deg, 2, &b, 1, false, false, &r) == CGPBStatusOK && r.count == 1 &&
               fabs(result_area(&r) - 25) < 1e-12, "zero-area contours add nothing");
    CGPBResultFree(&r);
    EXPECT(CGPBRegion(CGPBOpUnion, NULL, 0, NULL, 0, false, false, &r) == CGPBStatusOK && r.count == 0, "empty");
    CGPBResultFree(&r);
    /* NaN and infinity are refused, not silently dropped */
    CGPBPoint bad[3] = {{0, 0}, {NAN, 1}, {1, 0}};
    CGPBContour badc = {bad, 3, true};
    EXPECT(CGPBRegion(CGPBOpUnion, &badc, 1, &b, 1, false, false, &r) == CGPBStatusNonFinite, "NaN refused");
    bad[1] = (CGPBPoint) {INFINITY, 1};
    EXPECT(CGPBRegion(CGPBOpUnion, &a, 1, &badc, 1, false, false, &r) == CGPBStatusNonFinite, "inf refused");
    bad[1] = (CGPBPoint) {1.7e308, 1};
    bad[0] = (CGPBPoint) {-1.7e308, 0};
    EXPECT(CGPBRegion(CGPBOpUnion, &badc, 1, &b, 1, false, false, &r) == CGPBStatusTooLarge, "range overflow refused");

    /* lines */
    CGPBPoint ln[2] = {{-1, 1}, {5, 1}};
    rect(rb, 1, 0, 3, 2);
    CGPBContour line = {ln, 2, false};
    EXPECT(CGPBLines(true, &line, 1, &b, 1, false, &r) == CGPBStatusOK && r.count == 1 && !r.rings[0].closed &&
               r.rings[0].count == 2 && r.rings[0].points[0].x == 1 && r.rings[0].points[1].x == 3,
           "line intersection keeps x in [1,3]");
    CGPBResultFree(&r);
    EXPECT(CGPBLines(false, &line, 1, &b, 1, false, &r) == CGPBStatusOK && r.count == 2 &&
               r.rings[0].points[0].x == -1 && r.rings[0].points[1].x == 1 && r.rings[1].points[0].x == 3 &&
               r.rings[1].points[1].x == 5,
           "line subtraction keeps the two outer pieces");
    CGPBResultFree(&r);
    /* a closed contour crossing the region: pieces wrap around the start vertex into one run */
    CGPBPoint tri[3] = {{10, 10}, {2, 1}, {10, 1}};
    CGPBContour closedLine = {tri, 3, true};
    EXPECT(CGPBLines(false, &closedLine, 1, &b, 1, false, &r) == CGPBStatusOK && r.count == 1,
           "closed contour starting outside: the pieces around the start vertex form one open run (%zu runs)", r.count);
    CGPBResultFree(&r);
    /* a line along the mask boundary counts as inside */
    CGPBPoint edge[2] = {{1, -1}, {1, 4}};
    CGPBContour edgeLine = {edge, 2, false};
    EXPECT(CGPBLines(true, &edgeLine, 1, &b, 1, false, &r) == CGPBStatusOK && r.count == 1 &&
               r.rings[0].points[0].y == 0 && r.rings[0].points[r.rings[0].count - 1].y == 2,
           "boundary piece is kept by line intersection (GUESS pinned)");
    CGPBResultFree(&r);
}

/* a 2000-gon circle against a shifted copy and a star, to see the cost */
static void stress(void)
{
    enum { N = 2000 };
    static CGPBPoint c1[N], c2[N], star[N];
    for (int i = 0; i < N; i++) {
        double t = 2 * M_PI * i / N;
        c1[i] = (CGPBPoint) {100 * cos(t), 100 * sin(t)};
        c2[i] = (CGPBPoint) {50 + 100 * cos(t), 30 + 100 * sin(t)};
        double rr = (i % 2) ? 130 : 40;
        star[i] = (CGPBPoint) {rr * cos(t), rr * sin(t)};
    }
    CGPBContour a = {c1, N, true}, b = {c2, N, true}, s = {star, N, true};
    CGPBResult r;
    EXPECT(CGPBRegion(CGPBOpUnion, &a, 1, &b, 1, false, false, &r) == CGPBStatusOK && r.count == 1, "circle union");
    CGPBResultFree(&r);
    EXPECT(CGPBRegion(CGPBOpIntersection, &a, 1, &s, 1, true, false, &r) == CGPBStatusOK, "circle and star");
    CGPBResultFree(&r);
}

int main(int argc, char **argv)
{
    long scale = argc > 1 ? atol(argv[1]) : 1;
    if (argc > 2)
        rng_state ^= (uint64_t) atol(argv[2]) * 0x9E3779B97F4A7C15ull;
    fixtures();
    stress();
    fuzz("int-grid-4", 0, 4, 1, 0, 0, 3000 * scale);
    fuzz("int-grid-8", 0, 8, 1, 0, 0, 3000 * scale);
    fuzz("int-grid-30", 0, 30, 1, 0, 0, 1000 * scale);
    fuzz("float", 1, 10, 1, 0, 0, 3000 * scale);
    fuzz("float-big", 1, 10, 1e6, 1e9, -3e8, 1000 * scale);
    fuzz("float-small", 1, 10, 1e-6, 1e-3, 2e-3, 1000 * scale);
    fuzz("int-grid-offset", 0, 6, 0.1, 1e5, 1e5, 1000 * scale);
    if (failures) {
        fprintf(stderr, "%d FAILURES\n", failures);
        return 1;
    }
    puts("ALL PASS");
    return 0;
}
