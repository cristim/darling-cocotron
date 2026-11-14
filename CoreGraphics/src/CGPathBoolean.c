/* Boolean operations on polygon sets for Darling's Cocotron CoreGraphics.

   Written from scratch from the published descriptions of the method; no
   third-party code. Method:

   1. Snap every input vertex to an integer grid of 2^40 steps across the
      bounding box of all inputs (exact scaling by a power of two).
   2. Node the segments by snap rounding (Hobby, "Practical segment
      intersection with finite precision output", 1999; Guibas and Marimont,
      "Rounding arrangements dynamically", 1998). The hot pixels are the
      snapped vertices plus the rounded crossing points; every segment is
      replaced by the polyline through the centres of the hot pixels it
      touches. The result is a planar straight-line graph with integer
      vertices.
   3. Merge coincident edges, adding up their signed winding contributions
      (one count per input set).
   4. Label every edge with the winding numbers of both inputs on both of its
      sides with a left-to-right sweep that keeps the edges crossing the sweep line
      sorted (a vertical edge reads the sum just before its x). All comparisons
      are exact (128-bit integers).
   5. Keep the edges where the operation flips between inside and outside,
      directed so the interior is on the left, and trace them into rings.

   Tolerance: the grid is one. Every vertex moves by at most half a step, and
   the step is the extent of the joint bounding box divided by 2^40 (up to
   twice that). Within that, the arithmetic is exact.

   Cost: crossing detection is a sweep over x ranges, hot pixels are found
   through a cell index, labelling is a sweep that costs the number of edges
   times the number crossing the sweep line. Past fixed limits on the number
   of hot pixels and on the total work (CGPathBooleanInternal.h) the operation
   fails with CGPBStatusTooComplex instead of running on. */

#include "CGPathBooleanInternal.h"

static const Edge *pb_find_edge(const Graph *g, uint32_t u, uint32_t v)
{
    uint32_t a = u < v ? u : v, b = u < v ? v : u;
    size_t lo = 0, hi = g->edges.n;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        const Edge *e = &g->edges.v[mid];
        if (e->a == a && e->b == b)
            return e;
        if (e->a < a || (e->a == a && e->b < b))
            lo = mid + 1;
        else
            hi = mid;
    }
    return NULL;
}

CGPBStatus CGPBRegion(CGPBOp op, const CGPBContour *a, size_t na,
                      const CGPBContour *b, size_t nb, bool evenOdd,
                      bool wantGroups, CGPBResult *result)
{
    result->rings = NULL;
    result->count = 0;
    InputSet sets[2] = {{a, na, 0}, {b, op == CGPBOpNormalize ? 0 : nb, 1}};
    Graph g;
    memset(&g, 0, sizeof g);
    VecRing out = {0};
    VEC(DEdge) boundary = {0};
    VecIRing rings = {0};
    CGPBStatus st = pb_build_graph(&g, sets, 2, false);

    for (size_t i = 0; st == CGPBStatusOK && i < g.edges.n; i++) {
        const Edge *e = &g.edges.v[i];
        bool in[2];
        for (int side = 0; side < 2; side++) {
            const int *w = side == 0 ? e->wl : e->wr;
            bool ia = pb_in_rule(evenOdd, w[0]), ib = pb_in_rule(evenOdd, w[1]);
            switch (op) {
            case CGPBOpUnion: in[side] = ia || ib; break;
            case CGPBOpIntersection: in[side] = ia && ib; break;
            case CGPBOpSubtraction: in[side] = ia && !ib; break;
            case CGPBOpSymmetricDifference: in[side] = ia != ib; break;
            default: in[side] = ia; break;
            }
        }
        if (in[0] == in[1])
            continue;
        DEdge d = in[0] ? (DEdge) {e->a, e->b, 0} : (DEdge) {e->b, e->a, 0};
        if (!VPUSH(boundary, d))
            st = CGPBStatusNoMemory;
    }
    if (st == CGPBStatusOK)
        st = pb_trace_rings(&g, boundary.v, boundary.n, &rings);

    /* component grouping: a hole joins the smallest outer ring around it */
    size_t *group = NULL;
    if (st == CGPBStatusOK && rings.n > 0) {
        group = malloc(rings.n * sizeof(size_t));
        if (group == NULL)
            st = CGPBStatusNoMemory;
    }
    if (st == CGPBStatusOK && wantGroups) {
        for (size_t i = 0; i < rings.n; i++) {
            group[i] = i;
            if (!rings.v[i].hole)
                continue;
            const IRing *h = &rings.v[i];
            IPt p0 = vp(&g, h->ids.v[0]), p1 = vp(&g, h->ids.v[1]);
            IPt mid2 = {p0.x + p1.x, p0.y + p1.y};
            i128 bestArea = 0;
            for (size_t j = 0; j < rings.n; j++) {
                if (rings.v[j].hole || !pb_ring_contains_point2(&g, &rings.v[j], mid2))
                    continue;
                if (bestArea == 0 || rings.v[j].area2 < bestArea) {
                    bestArea = rings.v[j].area2;
                    group[i] = j;
                }
            }
        }
    }
    for (size_t i = 0; st == CGPBStatusOK && i < rings.n; i++) {
        if (!pb_result_push(&out, &g, rings.v[i].ids.v, rings.v[i].ids.n, true,
                         rings.v[i].hole, wantGroups ? group[i] : i))
            st = CGPBStatusNoMemory;
    }
    free(group);
    for (size_t i = 0; i < rings.n; i++)
        pb_iring_free(&rings.v[i]);
    VFREE(rings);
    VFREE(boundary);
    pb_graph_free(&g);
    return pb_finish(&out, st, result);
}

CGPBStatus CGPBLines(bool keepInside, const CGPBContour *a, size_t na,
                     const CGPBContour *b, size_t nb, bool evenOdd,
                     CGPBResult *result)
{
    result->rings = NULL;
    result->count = 0;
    InputSet sets[2] = {{a, na, 0}, {b, nb, 1}};
    Graph g;
    memset(&g, 0, sizeof g);
    VecRing out = {0};
    VecU32 seq = {0}, run = {0};
    VEC(uint8_t) keep = {0};
    CGPBStatus st = pb_build_graph(&g, sets, 2, true);

    for (size_t c = 0; st == CGPBStatusOK && c < g.lines.n; c++) {
        const LineContour *lc = &g.lines.v[c];
        seq.n = keep.n = 0;
        for (size_t s = lc->seg0; s < lc->seg0 + lc->nseg && st == CGPBStatusOK; s++) {
            const uint32_t *ids = g.ids.v + g.off.v[s];
            size_t n = g.off.v[s + 1] - g.off.v[s];
            for (size_t k = (seq.n ? 1 : 0); k < n; k++)
                if (!VPUSH(seq, ids[k]))
                    st = CGPBStatusNoMemory;
        }
        if (st != CGPBStatusOK || seq.n < 2)
            continue;
        size_t pieces = seq.n - 1;
        size_t allKept = 0;
        for (size_t i = 0; i < pieces && st == CGPBStatusOK; i++) {
            const Edge *e = pb_find_edge(&g, seq.v[i], seq.v[i + 1]);
            if (e == NULL) {
                st = CGPBStatusInconsistent;
                break;
            }
            bool inside = pb_in_rule(evenOdd, e->wl[1]) || pb_in_rule(evenOdd, e->wr[1]);
            uint8_t k = (inside == keepInside);
            allKept += k;
            if (!VPUSH(keep, k))
                st = CGPBStatusNoMemory;
        }
        if (st != CGPBStatusOK)
            break;
        if (allKept == 0)
            continue;
        if (lc->closed && allKept == pieces) {
            run.n = 0;
            for (size_t i = 0; i < pieces && st == CGPBStatusOK; i++)
                if (!VPUSH(run, seq.v[i]))
                    st = CGPBStatusNoMemory;
            if (st == CGPBStatusOK) {
                if (!pb_ring_simplify(&g, &run, true))
                    st = CGPBStatusNoMemory;
                else if (run.n >= 2 &&
                         /* a closed contour that retraces itself has no area: it is a line */
                         !pb_result_push(&out, &g, run.v, run.n, run.n >= 3, false, out.n))
                    st = CGPBStatusNoMemory;
            }
            continue;
        }
        /* start after a dropped piece so closed contours do not split a run */
        size_t first = 0;
        if (lc->closed)
            while (keep.v[first])
                first++;
        size_t total = pieces;
        size_t i = 0;
        while (i < total && st == CGPBStatusOK) {
            size_t pi = (first + i) % pieces;
            if (!keep.v[pi]) {
                i++;
                continue;
            }
            run.n = 0;
            if (!VPUSH(run, seq.v[pi]))
                st = CGPBStatusNoMemory;
            while (st == CGPBStatusOK && i < total && keep.v[(first + i) % pieces]) {
                size_t pj = (first + i) % pieces;
                if (!VPUSH(run, seq.v[pj + 1]))
                    st = CGPBStatusNoMemory;
                i++;
            }
            if (st != CGPBStatusOK)
                break;
            if (!pb_ring_simplify(&g, &run, false)) {
                st = CGPBStatusNoMemory;
                break;
            }
            if (run.n >= 2 && !pb_result_push(&out, &g, run.v, run.n, false, false, out.n))
                st = CGPBStatusNoMemory;
        }
    }
    VFREE(seq);
    VFREE(run);
    VFREE(keep);
    pb_graph_free(&g);
    return pb_finish(&out, st, result);
}
