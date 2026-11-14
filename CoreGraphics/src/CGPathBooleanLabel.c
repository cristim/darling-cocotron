/* Winding labels: the winding number of both inputs on both sides of every
   noded edge, from exact ray casts (see CGPathBoolean.c for the method). */

#include "CGPathBooleanInternal.h"

/* Both edges are non-vertical and canonical, and f spans the middle of e in x.
   Is f strictly below e there? Decided by an orientation test, not by
   evaluating y, so it is exact. */
static bool edge_below(IPt fa, IPt fb, IPt ea, IPt eb)
{
    if (fa.x >= ea.x) {
        i128 s = orient(ea, eb, fa);
        if (s == 0)
            s = orient(ea, eb, fb);
        return s < 0;
    }
    i128 s = orient(fa, fb, ea);
    if (s == 0)
        s = orient(fa, fb, eb);
    return s > 0;
}

CGPBStatus pb_label_edges(Graph *g)
{
    size_t n = g->edges.n;
    if (n == 0)
        return CGPBStatusOK;
    Keyed *cand = malloc(n * sizeof(Keyed)), *query = malloc(n * sizeof(Keyed));
    const Edge **active = malloc(n * sizeof(Edge *));
    if (cand == NULL || query == NULL || active == NULL) {
        free(cand);
        free(query);
        free(active);
        return CGPBStatusNoMemory;
    }
    size_t nc = 0, nq = 0;
    for (size_t i = 0; i < n; i++) {
        const Edge *e = &g->edges.v[i];
        if (vp(g, e->a).x == vp(g, e->b).x)
            continue;
        Keyed q = {vp(g, e->a).x + vp(g, e->b).x, i, e};
        query[nq++] = q;
        if (e->d[0] != 0 || e->d[1] != 0) {
            Keyed c = {vp(g, e->a).x, i, e};
            cand[nc++] = c;
        }
    }
    qsort(cand, nc, sizeof(Keyed), keyed_cmp);
    qsort(query, nq, sizeof(Keyed), keyed_cmp);

    size_t next = 0, na = 0;
    for (size_t qi = 0; qi < nq; qi++) {
        Edge *e = (Edge *) query[qi].ptr;
        IPt ea = vp(g, e->a), eb = vp(g, e->b);
        i64 xm2 = query[qi].key;
        while (next < nc && 2 * cand[next].key <= xm2)
            active[na++] = cand[next++].ptr;
        int w[2] = {0, 0};
        size_t keep = 0;
        for (size_t k = 0; k < na; k++) {
            const Edge *f = active[k];
            IPt fa = vp(g, f->a), fb = vp(g, f->b);
            if (2 * fb.x <= xm2)
                continue; /* ended before this query; queries only advance */
            active[keep++] = f;
            if (f == e)
                continue;
            if (edge_below(fa, fb, ea, eb)) {
                w[0] += f->d[0];
                w[1] += f->d[1];
            }
        }
        na = keep;
        for (int s = 0; s < 2; s++) {
            e->wr[s] = w[s];
            e->wl[s] = w[s] + e->d[s];
        }
    }

    /* vertical edges: left ray at the middle of the edge */
    for (size_t i = 0; i < n; i++) {
        Edge *e = &g->edges.v[i];
        IPt ea = vp(g, e->a), eb = vp(g, e->b);
        if (ea.x != eb.x)
            continue;
        i64 ym2 = ea.y + eb.y;
        int w[2] = {0, 0};
        for (size_t k = 0; k < n; k++) {
            const Edge *f = &g->edges.v[k];
            if (f == e || (f->d[0] == 0 && f->d[1] == 0))
                continue;
            IPt fa = vp(g, f->a), fb = vp(g, f->b);
            i64 dy = fb.y - fa.y;
            i64 lo2 = 2 * imin(fa.y, fb.y), hi2 = 2 * imax(fa.y, fb.y);
            if (dy == 0 || ym2 < lo2 || ym2 >= hi2)
                continue;
            if (fa.x > ea.x && fb.x > ea.x)
                continue;
            IPt fa2 = {2 * fa.x, 2 * fa.y}, fb2 = {2 * fb.x, 2 * fb.y};
            IPt pt2 = {2 * ea.x, ym2};
            int cr = sgn(orient(fa2, fb2, pt2));
            bool left = (cr < 0 && dy > 0) || (cr > 0 && dy < 0);
            if (!left)
                continue;
            int sign = dy > 0 ? -1 : 1;
            w[0] += sign * f->d[0];
            w[1] += sign * f->d[1];
        }
        for (int s = 0; s < 2; s++) {
            e->wl[s] = w[s];
            e->wr[s] = w[s] - e->d[s];
        }
    }
    free(cand);
    free(query);
    free(active);
    return CGPBStatusOK;
}
