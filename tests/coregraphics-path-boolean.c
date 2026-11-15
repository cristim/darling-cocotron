/* CGPath boolean operations through the public C API, in a Darling guest.
   Apple documents none of their results, so what is pinned here is marked
   GUESS, DEVIATION or observed in the check's message. The unmarked checks hold the fill-rule
   semantics every implementation must share: the result of an operation covers
   exactly the points the operation says, under either rule. */

#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;
#define EXPECT(cond, ...)                                                      \
    do {                                                                       \
        if (!(cond)) {                                                         \
            failures++;                                                        \
            fprintf(stderr, "FAIL line %d: ", __LINE__);                       \
            fprintf(stderr, __VA_ARGS__);                                      \
            fputc('\n', stderr);                                               \
        }                                                                      \
    } while (0)

typedef struct {
    int subpaths, moves, lines, curves, closes, openSubpaths;
    double area; /* signed area of the closed subpaths */
    CGPoint start, current;
    int inSubpath, closed;
} Stats;

static void count(void *info, const CGPathElement *e)
{
    Stats *s = info;
    switch (e->type) {
    case kCGPathElementMoveToPoint:
        if (s->inSubpath && !s->closed)
            s->openSubpaths++;
        s->subpaths++;
        s->moves++;
        s->start = s->current = e->points[0];
        s->inSubpath = 1;
        s->closed = 0;
        break;
    case kCGPathElementAddLineToPoint:
        s->lines++;
        s->area += (s->current.x * e->points[0].y - e->points[0].x * s->current.y) / 2;
        s->current = e->points[0];
        break;
    case kCGPathElementAddQuadCurveToPoint:
    case kCGPathElementAddCurveToPoint:
        s->curves++;
        break;
    case kCGPathElementCloseSubpath:
        s->closes++;
        s->area += (s->current.x * s->start.y - s->start.x * s->current.y) / 2;
        s->closed = 1;
        break;
    }
}

static Stats stats(CGPathRef p)
{
    Stats s = {0};
    CGPathApply(p, &s, count);
    if (s.inSubpath && !s.closed)
        s.openSubpaths++;
    return s;
}

typedef struct {
    int n;
    double area[8];
    int lines[8];
} Subs;

/* per-subpath signed area and line count of a result path (curves are not counted; releases the path) */
static void subs_visit(void *info, const CGPathElement *e)
{
    struct { Subs s; CGPoint cur, start; } *st = info;
    Subs *s = &st->s;
    switch (e->type) {
    case kCGPathElementMoveToPoint:
        if (s->n < 8) { s->area[s->n] = 0; s->lines[s->n] = 0; s->n++; }
        st->start = st->cur = e->points[0];
        break;
    case kCGPathElementAddLineToPoint:
        if (s->n > 0 && s->n <= 8) {
            s->area[s->n - 1] += (st->cur.x * e->points[0].y - e->points[0].x * st->cur.y) / 2;
            s->lines[s->n - 1]++;
        }
        st->cur = e->points[0];
        break;
    case kCGPathElementCloseSubpath:
        if (s->n > 0 && s->n <= 8)
            s->area[s->n - 1] += (st->cur.x * st->start.y - st->start.x * st->cur.y) / 2;
        st->cur = st->start;
        break;
    default:
        break;
    }
}

static Subs subs(CGPathRef p)
{
    struct { Subs s; CGPoint cur, start; } st;
    memset(&st, 0, sizeof st);
    if (p == NULL) {
        st.s.n = -1;
        return st.s;
    }
    CGPathApply(p, &st, subs_visit);
    CGPathRelease(p);
    return st.s;
}

static CGPathRef rect(double x, double y, double w, double h)
{
    return CGPathCreateWithRect(CGRectMake(x, y, w, h), NULL);
}

static int near(double a, double b)
{
    return fabs(a - b) < 1e-6;
}

/* sample points on a grid away from every grid line used by the fixtures */
static void check_cover(const char *name, CGPathRef result, bool evenOdd,
                        int (*want)(double, double), double limit)
{
    int bad = 0, total = 0;
    for (double x = -limit + 0.137; x < limit; x += 0.5) {
        for (double y = -limit + 0.213; y < limit; y += 0.5) {
            total++;
            bool got = CGPathContainsPoint(result, NULL, CGPointMake(x, y), evenOdd);
            if (got != (want(x, y) != 0))
                bad++;
        }
    }
    EXPECT(bad == 0, "%s: %d of %d sample points disagree", name, bad, total);
}

static CGPathRef gA, gB;
static bool gEvenOdd;
static int inA(double x, double y) { return CGPathContainsPoint(gA, NULL, CGPointMake(x, y), gEvenOdd); }
static int inB(double x, double y) { return CGPathContainsPoint(gB, NULL, CGPointMake(x, y), gEvenOdd); }
static int wantUnion(double x, double y) { return inA(x, y) || inB(x, y); }
static int wantIntersection(double x, double y) { return inA(x, y) && inB(x, y); }
static int wantSubtract(double x, double y) { return inA(x, y) && !inB(x, y); }
static int wantXor(double x, double y) { return inA(x, y) != inB(x, y); }

static uint64_t rs = 0x2545F4914F6CDD1Dull;
static double rnd(void)
{
    rs ^= rs << 13;
    rs ^= rs >> 7;
    rs ^= rs << 17;
    return (double) (rs >> 11) / 9007199254740992.0;
}

int main(void)
{
    /* two overlapping squares, 4 by 4 and offset by 2: union 28, overlap 4 */
    CGPathRef a = rect(0, 0, 4, 4), b = rect(2, 2, 4, 4);
    CGPathRef u = CGPathCreateCopyByUnioningPath(a, b, false);
    CGPathRef i = CGPathCreateCopyByIntersectingPath(a, b, false);
    CGPathRef s = CGPathCreateCopyBySubtractingPath(a, b, false);
    CGPathRef x = CGPathCreateCopyBySymmetricDifferenceOfPath(a, b, false);
    EXPECT(u && i && s && x, "all four operations return a path");
    gA = a;
    gB = b;
    gEvenOdd = false;
    check_cover("union", u, false, wantUnion, 8);
    check_cover("intersection", i, false, wantIntersection, 8);
    check_cover("subtraction", s, false, wantSubtract, 8);
    check_cover("symmetric difference", x, false, wantXor, 8);
    check_cover("union under even-odd", u, true, wantUnion, 8);
    EXPECT(near(fabs(stats(u).area), 28), "union area %g", stats(u).area);
    EXPECT(near(fabs(stats(i).area), 4), "intersection area %g", stats(i).area);
    EXPECT(near(fabs(stats(s).area), 12), "subtraction area %g", stats(s).area);
    EXPECT(near(fabs(stats(x).area), 24), "symmetric difference area %g", stats(x).area);
    CGRect ub = CGPathGetBoundingBox(u);
    EXPECT(near(ub.origin.x, 0) && near(ub.origin.y, 0) && near(ub.size.width, 6) && near(ub.size.height, 6),
           "union bounds");
    Stats su = stats(u);
    EXPECT(su.subpaths == 1 && su.closes == 1 && su.openSubpaths == 0 && su.curves == 0,
           "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): the union of two rectangles is one closed polygon subpath of straight segments (%d subpaths)",
           su.subpaths);
    EXPECT(su.lines == 7, "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): the union L-shape keeps its 8 corners, 7 lines then close (%d lines)", su.lines);
    EXPECT(stats(x).subpaths == 2, "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): the symmetric difference of two overlapping squares is two L-shaped subpaths (%d)",
           stats(x).subpaths);
    EXPECT(stats(s).subpaths == 1, "subtraction leaves one piece (%d)", stats(s).subpaths);
    CGPathRelease(u);
    CGPathRelease(i);
    CGPathRelease(s);
    CGPathRelease(x);

    /* the result is an owned copy independent of the inputs */
    CGPathRef u2 = CGPathCreateCopyByUnioningPath(a, a, false);
    EXPECT(u2 != a && u2 != NULL && near(fabs(stats(u2).area), 16), "union with itself is a new 4x4 path");
    CGPathRelease(u2);

    /* empty results are empty paths, not NULL */
    CGPathRef far = rect(100, 100, 1, 1);
    CGPathRef none = CGPathCreateCopyByIntersectingPath(a, far, false);
    EXPECT(none != NULL && CGPathIsEmpty(none), "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): an empty intersection is an empty path, not NULL");
    CGPathRelease(none);
    EXPECT(!CGPathIntersectsPath(a, far, false), "disjoint paths do not intersect");
    EXPECT(CGPathIntersectsPath(a, b, false), "overlapping paths intersect");
    CGPathRef inner = rect(1, 1, 1, 1);
    EXPECT(CGPathIntersectsPath(a, inner, false) && CGPathIntersectsPath(inner, a, false), "nested paths intersect");
    CGPathRef touch = rect(4, 0, 4, 4);
    EXPECT(!CGPathIntersectsPath(a, touch, false), "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): rectangles that only share an edge do not intersect");
    CGPathRef corner = rect(4, 4, 1, 1);
    EXPECT(!CGPathIntersectsPath(a, corner, false), "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): rectangles that only share a corner do not intersect");
    CGPathRelease(far);
    CGPathRelease(inner);
    CGPathRelease(touch);
    CGPathRelease(corner);

    /* NULL and non-finite inputs */
    EXPECT(CGPathCreateCopyByUnioningPath(NULL, b, false) == NULL, "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): NULL path gives NULL");
    EXPECT(CGPathCreateCopyByUnioningPath(a, NULL, false) == NULL, "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): NULL mask gives NULL");
    EXPECT(CGPathCreateCopyByNormalizing(NULL, false) == NULL, "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): normalizing NULL gives NULL");
    EXPECT(CGPathCreateSeparateComponents(NULL, false) == NULL, "GUESS: separating NULL gives NULL");
    EXPECT(!CGPathIntersectsPath(NULL, b, false), "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): intersects with NULL is false");
    CGMutablePathRef nanPath = CGPathCreateMutable();
    CGPathMoveToPoint(nanPath, NULL, 0, 0);
    CGPathAddLineToPoint(nanPath, NULL, NAN, 1);
    CGPathAddLineToPoint(nanPath, NULL, 1, 0);
    CGPathCloseSubpath(nanPath);
    EXPECT(CGPathCreateCopyByUnioningPath(nanPath, a, false) == NULL, "DEVIATION from the Mac (which drops the NaN subpath): a NaN coordinate gives NULL, loudly");
    EXPECT(!CGPathIntersectsPath(nanPath, a, false), "DEVIATION from the Mac: a NaN coordinate answers false, loudly");
    CGPathRelease(nanPath);

    /* fill rules: nested squares drawn the same way */
    CGMutablePathRef nested = CGPathCreateMutable();
    CGPathAddRect(nested, NULL, CGRectMake(0, 0, 10, 10));
    CGPathAddRect(nested, NULL, CGRectMake(3, 3, 4, 4));
    CGPathRef nw = CGPathCreateCopyByNormalizing(nested, false);
    CGPathRef ne = CGPathCreateCopyByNormalizing(nested, true);
    EXPECT(stats(nw).subpaths == 1 && near(fabs(stats(nw).area), 100), "winding fills the inner square too");
    EXPECT(stats(ne).subpaths == 2 && near(fabs(stats(ne).area), 84), "even-odd leaves a hole (area %g)", stats(ne).area);
    EXPECT(!CGPathContainsPoint(ne, NULL, CGPointMake(5, 5), false) && CGPathContainsPoint(ne, NULL, CGPointMake(1, 1), false),
           "the hole is a hole under the winding rule as well");
    CGPathRelease(nw);
    CGPathRelease(ne);

    /* components */
    CGMutablePathRef many = CGPathCreateMutable();
    CGPathAddRect(many, NULL, CGRectMake(0, 0, 10, 10));
    CGPathAddRect(many, NULL, CGRectMake(3, 3, 4, 4));   /* a hole under even-odd */
    CGPathAddRect(many, NULL, CGRectMake(4, 4, 2, 2));   /* an island in the hole */
    CGPathAddRect(many, NULL, CGRectMake(20, 0, 3, 3));  /* a separate piece */
    CFArrayRef parts = CGPathCreateSeparateComponents(many, true);
    EXPECT(parts != NULL && CFArrayGetCount(parts) == 3, "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): frame with hole, the island, and the far square are 3 components (got %ld)",
           parts ? (long) CFArrayGetCount(parts) : -1L);
    if (parts && CFArrayGetCount(parts) == 3) {
        int holes = 0, singles = 0;
        for (CFIndex k = 0; k < 3; k++) {
            Stats ps = stats((CGPathRef) CFArrayGetValueAtIndex(parts, k));
            holes += ps.subpaths == 2;
            singles += ps.subpaths == 1;
        }
        EXPECT(holes == 1 && singles == 2, "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): one component has two subpaths (outer and hole), two have one");
    }
    if (parts)
        CFRelease(parts);
    CGPathRelease(many);
    CGMutablePathRef empty = CGPathCreateMutable();
    CFArrayRef noParts = CGPathCreateSeparateComponents(empty, false);
    EXPECT(noParts != NULL && CFArrayGetCount(noParts) == 0, "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1): an empty path has no components (empty array)");
    if (noParts)
        CFRelease(noParts);
    CGPathRelease(empty);

    /* curves: a circle against a square; results hold no curve elements */
    CGPathRef circle = CGPathCreateWithEllipseInRect(CGRectMake(0, 0, 40, 40), NULL);
    CGPathRef sq = rect(20, 20, 40, 40);
    CGPathRef cu = CGPathCreateCopyByUnioningPath(circle, sq, false);
    Stats sc = stats(cu);
    EXPECT(sc.curves == 0 && sc.lines > 20, "DEVIATION from the Mac (which keeps Bezier curves): curves are flattened to line segments (%d curves, %d lines)", sc.curves, sc.lines);
    int bad = 0;
    for (double px = -2.31; px < 62; px += 1.7)
        for (double py = -2.17; py < 62; py += 1.7) {
            double r = hypot(px - 20, py - 20);
            bool inCircle = r < 20, nearCircle = fabs(r - 20) < 0.3;
            bool inSq = px > 20 && px < 60 && py > 20 && py < 60;
            bool nearSq = fabs(px - 20) < 0.3 || fabs(py - 20) < 0.3 || fabs(px - 60) < 0.3 || fabs(py - 60) < 0.3;
            if (nearCircle || nearSq)
                continue;
            if (CGPathContainsPoint(cu, NULL, CGPointMake(px, py), false) != (inCircle || inSq))
                bad++;
        }
    EXPECT(bad == 0, "circle union square disagrees at %d points", bad);
    EXPECT(fabs(stats(cu).area - (M_PI * 400 + 1600 - 0)) < 400, "union area %g is in the right range", stats(cu).area);
    CGPathRelease(cu);
    CGPathRelease(circle);
    CGPathRelease(sq);

    /* The values a real Mac gave for the same fixtures (macOS 26.1, probe
       stubs_f2_probe1, 40-unit squares), per subpath: signed area (outer rings
       positive, holes negative) and number of line segments. */
    {
        CGPathRef A = rect(0, 0, 40, 40), B = rect(20, 20, 40, 40), C = rect(40, 0, 40, 40), N = rect(10, 10, 10, 10);
        CGPathRef F = rect(100, 100, 10, 10);
        const char *o = "observed on a real Mac (macOS 26.1, probe stubs_f2_probe1)";
        for (int eo = 0; eo < 2; eo++) {
            Subs su = subs(CGPathCreateCopyByUnioningPath(A, B, eo));
            EXPECT(su.n == 1 && near(su.area[0], 2800) && su.lines[0] == 7, "%s: union of two overlapping squares is one 8-vertex subpath of area 2800 (%d subpaths)", o, su.n);
            Subs si = subs(CGPathCreateCopyByIntersectingPath(A, B, eo));
            EXPECT(si.n == 1 && near(si.area[0], 400) && si.lines[0] == 3, "%s: intersection is one square of area 400", o);
            Subs sb = subs(CGPathCreateCopyBySubtractingPath(A, B, eo));
            EXPECT(sb.n == 1 && near(sb.area[0], 1200) && sb.lines[0] == 5, "%s: subtraction is one 6-vertex subpath of area 1200", o);
            Subs sx = subs(CGPathCreateCopyBySymmetricDifferenceOfPath(A, B, eo));
            EXPECT(sx.n == 2 && near(sx.area[0], 1200) && near(sx.area[1], 1200) && sx.lines[0] == 5 && sx.lines[1] == 5,
                   "%s: symmetric difference is two 6-vertex subpaths of area 1200 each (%d)", o, sx.n);
        }
        Subs adj = subs(CGPathCreateCopyByUnioningPath(A, C, false));
        EXPECT(adj.n == 1 && near(adj.area[0], 3200) && adj.lines[0] == 3, "%s: adjacent squares merge into one 4-vertex rectangle", o);
        Subs same = subs(CGPathCreateCopyByUnioningPath(A, A, false));
        EXPECT(same.n == 1 && near(same.area[0], 1600) && same.lines[0] == 3, "%s: a path united with itself is one 4-vertex square", o);
        CGPathRef zero = CGPathCreateCopyBySubtractingPath(A, A, false);
        EXPECT(zero != NULL && CGPathIsEmpty(zero), "%s: a path minus itself is an empty path", o);
        Subs hole = subs(CGPathCreateCopyBySubtractingPath(A, N, false));
        EXPECT(hole.n == 2 && near(hole.area[0], 1600) && near(hole.area[1], -100), "%s: a square minus a nested one is the outer ring (1600) then the hole (-100)", o);
        Subs nest = subs(CGPathCreateCopyByNormalizing(nested, false));
        EXPECT(nest.n == 1 && near(nest.area[0], 100), "%s: winding normalize of same-direction nested squares is one subpath", o);
        CGMutablePathRef nest2 = CGPathCreateMutable();
        CGPathAddRect(nest2, NULL, CGRectMake(0, 0, 60, 60));
        CGPathAddRect(nest2, NULL, CGRectMake(20, 20, 20, 20));
        Subs nw = subs(CGPathCreateCopyByNormalizing(nest2, false)), ne = subs(CGPathCreateCopyByNormalizing(nest2, true));
        EXPECT(nw.n == 1 && near(nw.area[0], 3600), "%s: winding normalize gives one subpath of area 3600", o);
        EXPECT(ne.n == 2 && near(ne.area[0], 3600) && near(ne.area[1], -400), "%s: even-odd normalize gives the outer ring 3600 and a hole -400", o);
        CGMutablePathRef bow2 = CGPathCreateMutable();
        CGPathMoveToPoint(bow2, NULL, 0, 0); CGPathAddLineToPoint(bow2, NULL, 40, 40);
        CGPathAddLineToPoint(bow2, NULL, 40, 0); CGPathAddLineToPoint(bow2, NULL, 0, 40); CGPathCloseSubpath(bow2);
        for (int eo = 0; eo < 2; eo++) {
            Subs bw = subs(CGPathCreateCopyByNormalizing(bow2, eo));
            EXPECT(bw.n == 2 && near(bw.area[0], 400) && near(bw.area[1], 400), "%s: a bowtie normalizes into two positive triangles of 400 (rule %d)", o, eo);
        }
        CGMutablePathRef opn = CGPathCreateMutable();
        CGPathMoveToPoint(opn, NULL, 0, 0); CGPathAddLineToPoint(opn, NULL, 40, 0); CGPathAddLineToPoint(opn, NULL, 40, 40);
        Subs ot = subs(CGPathCreateCopyByUnioningPath(opn, F, false));
        EXPECT(ot.n == 2 && ((near(ot.area[0], 800) && near(ot.area[1], 100)) || (near(ot.area[0], 100) && near(ot.area[1], 800))),
               "%s: an open triangle is filled as if closed (areas 800 and 100; the order of the subpaths is not matched)", o);
        CGMutablePathRef emp = CGPathCreateMutable(), lone2 = CGPathCreateMutable();
        CGPathMoveToPoint(lone2, NULL, 5, 5);
        Subs ue = subs(CGPathCreateCopyByUnioningPath(A, emp, false)), ul = subs(CGPathCreateCopyByUnioningPath(A, lone2, false));
        EXPECT(ue.n == 1 && near(ue.area[0], 1600) && ul.n == 1 && near(ul.area[0], 1600), "%s: an empty path or a lone moveto adds nothing to a union", o);
        CGPathRef ee = CGPathCreateCopyByUnioningPath(emp, emp, false);
        EXPECT(ee != NULL && CGPathIsEmpty(ee), "%s: empty united with empty is empty", o);
        EXPECT(!CGPathIntersectsPath(A, emp, false), "%s: nothing intersects an empty path", o);
        CGMutablePathRef cmany = CGPathCreateMutable();
        CGPathAddRect(cmany, NULL, CGRectMake(0, 0, 100, 100));
        CGPathAddRect(cmany, NULL, CGRectMake(30, 30, 40, 40));
        CGPathAddRect(cmany, NULL, CGRectMake(40, 40, 20, 20));
        CGPathAddRect(cmany, NULL, CGRectMake(200, 0, 30, 30));
        CFArrayRef w2 = CGPathCreateSeparateComponents(cmany, false);
        EXPECT(w2 != NULL && CFArrayGetCount(w2) == 2, "%s: winding gives two components (outer square and far square)", o);
        if (w2) CFRelease(w2);
        CGPathRelease(cmany);
    }

    /* random polygons against CGPathContainsPoint under both rules */
    int randomBad = 0, randomPoints = 0;
    for (int it = 0; it < 150; it++) {
        CGMutablePathRef pa = CGPathCreateMutable(), pb = CGPathCreateMutable();
        for (int k = 0; k < 2; k++) {
            CGMutablePathRef p = k ? pb : pa;
            int n = 3 + (int) (rnd() * 6);
            for (int v = 0; v < n; v++) {
                double px = floor(rnd() * 9), py = floor(rnd() * 9);
                if (v == 0)
                    CGPathMoveToPoint(p, NULL, px, py);
                else
                    CGPathAddLineToPoint(p, NULL, px, py);
            }
            CGPathCloseSubpath(p);
        }
        gA = pa;
        gB = pb;
        for (int eo = 0; eo < 2; eo++) {
            gEvenOdd = eo;
            CGPathRef res[4] = {CGPathCreateCopyByUnioningPath(pa, pb, eo), CGPathCreateCopyByIntersectingPath(pa, pb, eo),
                                CGPathCreateCopyBySubtractingPath(pa, pb, eo),
                                CGPathCreateCopyBySymmetricDifferenceOfPath(pa, pb, eo)};
            int (*want[4])(double, double) = {wantUnion, wantIntersection, wantSubtract, wantXor};
            for (int op = 0; op < 4; op++) {
                if (res[op] == NULL) {
                    randomBad++;
                    continue;
                }
                for (int k = 0; k < 40; k++) {
                    double px = rnd() * 9 - 0.5 + 1e-3, py = rnd() * 9 - 0.5 + 1e-3;
                    randomPoints++;
                    /* the inputs' own answer is the oracle; skip points that could sit on an input edge */
                    int w1 = want[op](px, py);
                    int w2 = want[op](px + 1e-5, py + 1e-5);
                    if (w1 != w2)
                        continue;
                    if ((CGPathContainsPoint(res[op], NULL, CGPointMake(px, py), eo) != 0) != (w1 != 0))
                        randomBad++;
                }
                CGPathRelease(res[op]);
            }
        }
        CGPathRelease(pa);
        CGPathRelease(pb);
    }
    EXPECT(randomBad == 0, "random polygons: %d of %d samples disagree with CGPathContainsPoint", randomBad, randomPoints);

    CGPathRelease(a);
    CGPathRelease(b);
    if (failures) {
        fprintf(stderr, "%d FAILURES\n", failures);
        return 1;
    }
    puts("ALL PASS");
    return 0;
}
