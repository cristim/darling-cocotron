/* Snapping, noding and edge merging: turns input contours into a planar graph
   with integer vertices (see CGPathBoolean.c for the method). */

#include "CGPathBooleanInternal.h"

void pb_graph_free(Graph *g)
{
    VFREE(g->hv);
    VFREE(g->segs);
    VFREE(g->lines);
    VFREE(g->off);
    VFREE(g->ids);
    VFREE(g->edges);
}

static int hv_cmp(const void *pa, const void *pb)
{
    const HV *a = pa, *b = pb;
    int c = ipt_cmp(a->p, b->p);
    if (c != 0)
        return c;
    if (a->orig != b->orig)
        return b->orig - a->orig; /* input vertices first */
    /* Two input vertices in one pixel: keep the same one on every libc. */
    if (a->x != b->x)
        return a->x < b->x ? -1 : 1;
    return a->y < b->y ? -1 : a->y > b->y;
}

bool pb_find_vertex(const Graph *g, IPt p, uint32_t *id)
{
    size_t lo = 0, hi = g->hv.n;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        int c = ipt_cmp(g->hv.v[mid].p, p);
        if (c == 0) {
            *id = (uint32_t) mid;
            return true;
        }
        if (c < 0)
            lo = mid + 1;
        else
            hi = mid;
    }
    return false;
}

static CGPBStatus pb_grid_init(Grid *grid, const InputSet *sets, size_t nsets)
{
    double minx = INFINITY, miny = INFINITY, maxx = -INFINITY, maxy = -INFINITY;
    bool any = false;
    for (size_t s = 0; s < nsets; s++) {
        for (size_t i = 0; i < sets[s].count; i++) {
            const CGPBContour *c = &sets[s].list[i];
            for (size_t k = 0; k < c->count; k++) {
                double x = c->points[k].x, y = c->points[k].y;
                if (!isfinite(x) || !isfinite(y))
                    return CGPBStatusNonFinite;
                any = true;
                if (x < minx) minx = x;
                if (x > maxx) maxx = x;
                if (y < miny) miny = y;
                if (y > maxy) maxy = y;
            }
        }
    }
    grid->ox = grid->oy = 0;
    grid->shift = 0;
    if (!any)
        return CGPBStatusOK;
    double extent = fmax(maxx - minx, maxy - miny);
    if (!isfinite(extent))
        return CGPBStatusTooLarge;
    int e = 1;
    if (extent > 0)
        frexp(extent, &e); /* extent < 2^e */
    grid->ox = minx;
    grid->oy = miny;
    grid->shift = GRID_BITS - e;
    return CGPBStatusOK;
}

static CGPBStatus pb_add_contour(Graph *g, VecHV *tmp, const CGPBContour *c,
                              uint8_t src, bool closed)
{
    tmp->n = 0;
    for (size_t k = 0; k < c->count; k++) {
        IPt p = grid_snap(&g->grid, c->points[k].x, c->points[k].y);
        if (tmp->n > 0 && ipt_eq(tmp->v[tmp->n - 1].p, p))
            continue;
        HV v = {p, c->points[k].x, c->points[k].y, 1};
        if (!VPUSH(*tmp, v))
            return CGPBStatusNoMemory;
    }
    while (closed && tmp->n > 1 && ipt_eq(tmp->v[0].p, tmp->v[tmp->n - 1].p))
        tmp->n--;
    size_t n = tmp->n;
    bool region = src != 2;
    if ((region && n < 3) || (!region && n < 2))
        return CGPBStatusOK;

    size_t seg0 = g->segs.n;
    size_t nseg = closed ? n : n - 1;
    for (size_t k = 0; k < nseg; k++) {
        Seg s = {tmp->v[k].p, tmp->v[(k + 1) % n].p, src};
        if (!VPUSH(g->segs, s))
            return CGPBStatusNoMemory;
    }
    for (size_t k = 0; k < n; k++)
        if (!VPUSH(g->hv, tmp->v[k]))
            return CGPBStatusNoMemory;
    if (!region) {
        LineContour lc = {seg0, nseg, closed};
        if (!VPUSH(g->lines, lc))
            return CGPBStatusNoMemory;
    }
    return CGPBStatusOK;
}

static CGPBStatus find_crossings(Graph *g)
{
    size_t n = g->segs.n;
    if (n < 2)
        return CGPBStatusOK;
    Keyed *idx = malloc(n * sizeof(Keyed));
    if (idx == NULL)
        return CGPBStatusNoMemory;
    for (size_t i = 0; i < n; i++) {
        Keyed k = {imin(g->segs.v[i].p.x, g->segs.v[i].q.x), i, NULL};
        idx[i] = k;
    }
    qsort(idx, n, sizeof(Keyed), keyed_cmp);

    CGPBStatus st = CGPBStatusOK;
    for (size_t i = 0; i < n && st == CGPBStatusOK; i++) {
        const Seg *a = &g->segs.v[idx[i].idx];
        i64 axmax = imax(a->p.x, a->q.x);
        i64 aymin = imin(a->p.y, a->q.y), aymax = imax(a->p.y, a->q.y);
        for (size_t j = i + 1; j < n; j++) {
            const Seg *b = &g->segs.v[idx[j].idx];
            if (imin(b->p.x, b->q.x) > axmax)
                break;
            if (imin(b->p.y, b->q.y) > aymax || imax(b->p.y, b->q.y) < aymin)
                continue;
            int o1 = sgn(orient(a->p, a->q, b->p));
            int o2 = sgn(orient(a->p, a->q, b->q));
            int o3 = sgn(orient(b->p, b->q, a->p));
            int o4 = sgn(orient(b->p, b->q, a->q));
            if (o1 * o2 >= 0 || o3 * o4 >= 0)
                continue; /* not a proper crossing; touches are hot pixels already */
            i128 dax = a->q.x - a->p.x, day = a->q.y - a->p.y;
            i128 dbx = b->q.x - b->p.x, dby = b->q.y - b->p.y;
            i128 den = dax * dby - day * dbx;
            i128 num = (i128) (b->p.x - a->p.x) * dby - (i128) (b->p.y - a->p.y) * dbx;
            IPt c;
            c.x = a->p.x + (i64) round_div(dax * num, den);
            c.y = a->p.y + (i64) round_div(day * num, den);
            HV v = {c, 0, 0, 0};
            grid_unsnap(&g->grid, c, &v.x, &v.y);
            if (!VPUSH(g->hv, v)) {
                st = CGPBStatusNoMemory;
                break;
            }
        }
    }
    free(idx);
    return st;
}

static int hit_cmp(const void *pa, const void *pb)
{
    const Hit *a = pa, *b = pb;
    if (a->key != b->key)
        return a->key < b->key ? -1 : 1;
    return a->id < b->id ? -1 : a->id > b->id;
}

/* Does the segment p-q touch the closed unit pixel centred on c? */
static bool pixel_touched(IPt p, IPt q, IPt c)
{
    IPt p2 = {2 * p.x, 2 * p.y}, q2 = {2 * q.x, 2 * q.y};
    IPt k[4] = {{2 * c.x - 1, 2 * c.y - 1}, {2 * c.x + 1, 2 * c.y - 1},
                {2 * c.x + 1, 2 * c.y + 1}, {2 * c.x - 1, 2 * c.y + 1}};
    int pos = 0, neg = 0;
    for (int i = 0; i < 4; i++) {
        int s = sgn(orient(p2, q2, k[i]));
        pos += s > 0;
        neg += s < 0;
    }
    return !(pos == 4 || neg == 4);
}

static CGPBStatus node_segments(Graph *g)
{
    CGPBStatus st = find_crossings(g);
    if (st != CGPBStatusOK)
        return st;

    if (g->hv.n > 0)
        qsort(g->hv.v, g->hv.n, sizeof(HV), hv_cmp);
    size_t out = 0;
    for (size_t i = 0; i < g->hv.n; i++) {
        if (out > 0 && ipt_eq(g->hv.v[out - 1].p, g->hv.v[i].p))
            continue;
        g->hv.v[out++] = g->hv.v[i];
    }
    g->hv.n = out;

    VEC(Hit) hits = {0};
    for (size_t s = 0; s < g->segs.n; s++) {
        const Seg *seg = &g->segs.v[s];
        uint32_t idp, idq;
        if (!pb_find_vertex(g, seg->p, &idp) || !pb_find_vertex(g, seg->q, &idq)) {
            VFREE(hits);
            return CGPBStatusInconsistent;
        }
        if (!VPUSH(g->off, g->ids.n)) {
            VFREE(hits);
            return CGPBStatusNoMemory;
        }
        hits.n = 0;
        i64 xmin = imin(seg->p.x, seg->q.x), xmax = imax(seg->p.x, seg->q.x);
        i64 ymin = imin(seg->p.y, seg->q.y), ymax = imax(seg->p.y, seg->q.y);
        size_t lo = 0, hi = g->hv.n;
        while (lo < hi) {
            size_t mid = (lo + hi) / 2;
            if (g->hv.v[mid].p.x < xmin)
                lo = mid + 1;
            else
                hi = mid;
        }
        for (size_t i = lo; i < g->hv.n && g->hv.v[i].p.x <= xmax; i++) {
            IPt c = g->hv.v[i].p;
            if (c.y < ymin || c.y > ymax || i == idp || i == idq)
                continue;
            if (!pixel_touched(seg->p, seg->q, c))
                continue;
            Hit h = {(i128) (c.x - seg->p.x) * (seg->q.x - seg->p.x) +
                         (i128) (c.y - seg->p.y) * (seg->q.y - seg->p.y),
                     (uint32_t) i};
            if (!VPUSH(hits, h)) {
                VFREE(hits);
                return CGPBStatusNoMemory;
            }
        }
        if (hits.n > 1)
            qsort(hits.v, hits.n, sizeof(Hit), hit_cmp);
        bool ok = VPUSH(g->ids, idp);
        for (size_t i = 0; ok && i < hits.n; i++)
            if (hits.v[i].id != g->ids.v[g->ids.n - 1])
                ok = VPUSH(g->ids, hits.v[i].id);
        if (ok && g->ids.v[g->ids.n - 1] != idq)
            ok = VPUSH(g->ids, idq);
        if (!ok) {
            VFREE(hits);
            return CGPBStatusNoMemory;
        }
    }
    VFREE(hits);
    if (!VPUSH(g->off, g->ids.n))
        return CGPBStatusNoMemory;
    return CGPBStatusOK;
}

static int edge_cmp(const void *pa, const void *pb)
{
    const Edge *a = pa, *b = pb;
    if (a->a != b->a)
        return a->a < b->a ? -1 : 1;
    return a->b < b->b ? -1 : a->b > b->b;
}

static CGPBStatus build_edges(Graph *g)
{
    for (size_t s = 0; s < g->segs.n; s++) {
        const uint32_t *ids = g->ids.v + g->off.v[s];
        size_t n = g->off.v[s + 1] - g->off.v[s];
        for (size_t k = 0; k + 1 < n; k++) {
            uint32_t u = ids[k], v = ids[k + 1];
            if (u == v)
                continue;
            Edge e;
            memset(&e, 0, sizeof e);
            e.a = u < v ? u : v;
            e.b = u < v ? v : u;
            int sign = u < v ? 1 : -1;
            if (g->segs.v[s].src == 2)
                e.line = 1;
            else
                e.d[g->segs.v[s].src] = sign;
            if (!VPUSH(g->edges, e))
                return CGPBStatusNoMemory;
        }
    }
    if (g->edges.n > 0)
        qsort(g->edges.v, g->edges.n, sizeof(Edge), edge_cmp);
    size_t out = 0;
    for (size_t i = 0; i < g->edges.n; i++) {
        Edge *e = &g->edges.v[i];
        if (out > 0 && g->edges.v[out - 1].a == e->a && g->edges.v[out - 1].b == e->b) {
            Edge *m = &g->edges.v[out - 1];
            m->d[0] += e->d[0];
            m->d[1] += e->d[1];
            m->line |= e->line;
            continue;
        }
        g->edges.v[out++] = *e;
    }
    size_t keep = 0;
    for (size_t i = 0; i < out; i++) {
        const Edge *e = &g->edges.v[i];
        if (e->d[0] == 0 && e->d[1] == 0 && !e->line)
            continue;
        g->edges.v[keep++] = *e;
    }
    g->edges.n = keep;
    return CGPBStatusOK;
}

CGPBStatus pb_build_graph(Graph *g, const InputSet *sets, size_t nsets,
                              bool linesInA)
{
    CGPBStatus st = pb_grid_init(&g->grid, sets, nsets);
    if (st != CGPBStatusOK)
        return st;
    VecHV tmp = {0};
    for (size_t s = 0; s < nsets && st == CGPBStatusOK; s++) {
        for (size_t i = 0; i < sets[s].count && st == CGPBStatusOK; i++) {
            const CGPBContour *c = &sets[s].list[i];
            bool isLine = linesInA && sets[s].src == 0;
            st = pb_add_contour(g, &tmp, c, isLine ? 2 : sets[s].src,
                             isLine ? c->closed : true);
        }
    }
    VFREE(tmp);
    if (st == CGPBStatusOK)
        st = node_segments(g);
    if (st == CGPBStatusOK)
        st = build_edges(g);
    if (st == CGPBStatusOK)
        st = pb_label_edges(g);
    return st;
}
