/* Winding labels: the winding number of both inputs on both sides of every
   noded edge (see CGPathBoolean.c for the method).

   A sweep from left to right keeps the non-vertical edges that cross the sweep
   line sorted from bottom to top. The edges of a noded graph never cross, so
   their order is the same wherever two of them overlap in x, and an
   orientation test decides it exactly. The winding number below an edge is the
   sum of the weights of the edges under it, which is its right side (the edge
   runs left to right); the left side adds its own weight. A vertical edge looks
   at the sweep line just before it: the sum under its middle point is the
   winding on its left (its upward direction has the left on the west). */

#include "CGPathBooleanInternal.h"

/* Both edges are non-vertical and canonical, and their open x ranges overlap.
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

/* An active edge with its weights at hand, so the sums below walk one array.
   Bit 0 of `ep` marks an edge inserted at the current x that has no label yet. */
typedef struct {
    uintptr_t ep;
    int d[2];
} AEntry;

typedef struct {
    AEntry *v;
    size_t n;
} Active;

static Edge *entry_edge(const AEntry *a)
{
    return (Edge *) (a->ep & ~(uintptr_t) 1);
}

static void sum_below(const Active *act, size_t count, int w[2])
{
    w[0] = w[1] = 0;
    for (size_t i = 0; i < count; i++) {
        w[0] += act->v[i].d[0];
        w[1] += act->v[i].d[1];
    }
}

/* Winding on the left of a vertical edge, from the actives just before its x. */
static void label_vertical(const Graph *g, const Active *act, Edge *e)
{
    IPt ea = vp(g, e->a), eb = vp(g, e->b);
    IPt pt2 = {2 * ea.x, ea.y + eb.y}; /* the middle of the edge, doubled */
    size_t lo = 0, hi = act->n;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        const Edge *f = entry_edge(&act->v[mid]);
        IPt fa = vp(g, f->a), fb = vp(g, f->b);
        IPt fa2 = {2 * fa.x, 2 * fa.y}, fb2 = {2 * fb.x, 2 * fb.y};
        if (orient(fa2, fb2, pt2) < 0) /* the point is under f: f is above it */
            hi = mid;
        else
            lo = mid + 1;
    }
    int w[2];
    sum_below(act, hi, w);
    for (int s = 0; s < 2; s++) {
        e->wl[s] = w[s];
        e->wr[s] = w[s] - e->d[s];
    }
}

CGPBStatus pb_label_edges(Graph *g)
{
    size_t n = g->edges.n;
    if (n == 0)
        return CGPBStatusOK;
    Keyed *ins = malloc(n * sizeof(Keyed)), *rem = malloc(n * sizeof(Keyed));
    Keyed *vert = malloc(n * sizeof(Keyed));
    Active act = {malloc(n * sizeof(AEntry)), 0};
    CGPBStatus st = CGPBStatusOK;
    if (ins == NULL || rem == NULL || vert == NULL || act.v == NULL) {
        st = CGPBStatusNoMemory;
        goto done;
    }
    size_t ni = 0, nr = 0, nv = 0;
    for (size_t i = 0; i < n; i++) {
        Edge *e = &g->edges.v[i];
        IPt ea = vp(g, e->a), eb = vp(g, e->b);
        if (ea.x == eb.x) {
            Keyed k = {ea.x, i, e};
            vert[nv++] = k;
        } else {
            Keyed a = {ea.x, i, e}, b = {eb.x, i, e};
            ins[ni++] = a;
            rem[nr++] = b;
        }
    }
    qsort(ins, ni, sizeof(Keyed), keyed_cmp);
    qsort(rem, nr, sizeof(Keyed), keyed_cmp);
    qsort(vert, nv, sizeof(Keyed), keyed_cmp);

    size_t ii = 0, ri = 0, vi = 0;
    while (ii < ni || ri < nr || vi < nv) {
        i64 x = INT64_MAX;
        if (ii < ni) x = imin(x, ins[ii].key);
        if (ri < nr) x = imin(x, rem[ri].key);
        if (vi < nv) x = imin(x, vert[vi].key);
        /* verticals first: the actives are the edges crossing just left of x */
        while (vi < nv && vert[vi].key == x) {
            label_vertical(g, &act, (Edge *) vert[vi++].ptr);
            g->work += act.n;
        }
        while (ri < nr && rem[ri].key == x) {
            const Edge *e = rem[ri++].ptr;
            size_t k = 0;
            while (k < act.n && entry_edge(&act.v[k]) != e)
                k++;
            g->work += k;
            if (k == act.n) {
                st = CGPBStatusInconsistent;
                goto done;
            }
            memmove(act.v + k, act.v + k + 1, (act.n - k - 1) * sizeof(AEntry));
            act.n--;
            g->work += act.n - k + 1;
        }
        size_t inserted = 0, last = 0; /* last: index of the rightmost unlabelled entry */
        while (ii < ni && ins[ii].key == x) {
            Edge *e = (Edge *) ins[ii++].ptr;
            IPt ea = vp(g, e->a), eb = vp(g, e->b);
            size_t lo = 0, hi = act.n;
            while (lo < hi) {
                size_t mid = (lo + hi) / 2;
                const Edge *f = entry_edge(&act.v[mid]);
                if (edge_below(vp(g, f->a), vp(g, f->b), ea, eb))
                    lo = mid + 1;
                else
                    hi = mid;
            }
            memmove(act.v + lo + 1, act.v + lo, (act.n - lo) * sizeof(AEntry));
            AEntry entry = {(uintptr_t) e | 1, {e->d[0], e->d[1]}};
            act.v[lo] = entry;
            act.n++;
            last = (inserted == 0 || lo > last) ? lo : last + 1;
            inserted++;
            g->work += act.n - lo;
        }
        /* Every edge that starts at x is in place, so one pass over the part
           of the sweep line up to the last of them gives each its winding
           below. */
        if (inserted > 0) {
            int w[2] = {0, 0};
            for (size_t k = 0; k <= last; k++) {
                AEntry *a = &act.v[k];
                if (a->ep & 1) {
                    Edge *e = entry_edge(a);
                    for (int s = 0; s < 2; s++) {
                        e->wr[s] = w[s];
                        e->wl[s] = w[s] + e->d[s];
                    }
                    a->ep &= ~(uintptr_t) 1;
                }
                w[0] += a->d[0];
                w[1] += a->d[1];
            }
            g->work += last + 1;
        }
        if (g->work > PB_WORK_LIMIT) {
            st = CGPBStatusTooComplex;
            goto done;
        }
    }
done:
    free(ins);
    free(rem);
    free(vert);
    free(act.v);
    return st;
}
