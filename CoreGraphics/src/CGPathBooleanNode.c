/* Snapping, noding and edge merging: turns input contours into a planar graph
   with integer vertices (see CGPathBoolean.c for the method). */

#include "CGPathBooleanInternal.h"

void pb_graph_free(Graph *g)
{
    VFREE(g->hv);
    VFREE(g->segs);
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
    /* The grid is a tolerance: every vertex moves by at most half a step, and
       the step is extent / 2^40 (between extent / 2^41 and extent / 2^40) for the
       joint bounding box of both inputs. A 1e-3 square next to a 1e9 one is
       snapped to a 1/512 grid. */
    grid->ox = minx;
    grid->oy = miny;
    grid->shift = GRID_BITS - e;
    return CGPBStatusOK;
}

static CGPBStatus pb_add_contour(Graph *g, VecHV *tmp, const CGPBContour *c, uint8_t src)
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
    while (tmp->n > 1 && ipt_eq(tmp->v[0].p, tmp->v[tmp->n - 1].p))
        tmp->n--;
    size_t n = tmp->n;
    if (n < 3)
        return CGPBStatusOK;

    for (size_t k = 0; k < n; k++) {
        IPt p = tmp->v[k].p, q = tmp->v[(k + 1) % n].p;
        Seg s = {p, q, src, 1};
        if (ipt_cmp(p, q) > 0) {
            s.p = q;
            s.q = p;
            s.w = -1;
        }
        if (!VPUSH(g->segs, s))
            return CGPBStatusNoMemory;
    }
    for (size_t k = 0; k < n; k++)
        if (!VPUSH(g->hv, tmp->v[k]))
            return CGPBStatusNoMemory;
    return CGPBStatusOK;
}

static int seg_cmp(const void *pa, const void *pb)
{
    const Seg *a = pa, *b = pb;
    int c = ipt_cmp(a->p, b->p);
    if (c == 0)
        c = ipt_cmp(a->q, b->q);
    if (c == 0)
        c = (int) a->src - (int) b->src;
    return c;
}

/* Merge equal segments of one set, adding their weights, and drop the ones
   that cancel. This keeps many coincident or retraced edges (a path drawn
   twice, 16000 identical squares) from costing a pair test each. */
static void dedupe_region_segments(Graph *g)
{
    Seg *r = g->segs.v;
    size_t n = g->segs.n;
    if (n < 2)
        return;
    qsort(r, n, sizeof(Seg), seg_cmp);
    size_t out = 0;
    for (size_t i = 0; i < n; i++) {
        if (out > 0 && seg_cmp(&r[out - 1], &r[i]) == 0)
            r[out - 1].w += r[i].w;
        else
            r[out++] = r[i];
    }
    size_t keep = 0;
    for (size_t i = 0; i < out; i++)
        if (r[i].w != 0)
            r[keep++] = r[i];
    g->segs.n = keep;
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
            g->work++;
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
            if (g->hv.n >= PB_MAX_HOT_PIXELS) {
                st = CGPBStatusTooComplex;
                break;
            }
            if (!VPUSH(g->hv, v)) {
                st = CGPBStatusNoMemory;
                break;
            }
        }
        if (st == CGPBStatusOK && g->work > PB_WORK_LIMIT)
            st = CGPBStatusTooComplex;
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

/* Does the segment p-q touch the closed unit pixel centred on c? The corners
   of the pixel are c + (+-1/2, +-1/2) and the cross product is linear, so the
   segment misses the pixel exactly when |cross| exceeds (|dx| + |dy|) / 2 (all
   four corners on one side of the line), given that their bounding boxes
   overlap, which the caller checks. */
static bool pixel_touched(IPt p, IPt q, IPt c)
{
    i128 o = orient(p, q, c);
    i128 reach = (i128) (q.x > p.x ? q.x - p.x : p.x - q.x) + (q.y > p.y ? q.y - p.y : p.y - q.y);
    return 2 * (o < 0 ? -o : o) <= reach;
}

typedef VEC(Hit) VecHit;

/* The hot pixels in square cells of `side` grid steps, by counting sort, so a
   segment only looks at the cells it passes through. */
typedef struct {
    IPt p;
    uint32_t id;
} PixelItem;

typedef struct {
    i64 side;
    size_t ncx;
    size_t *start;    /* ncells + 1 offsets into items */
    PixelItem *items; /* vertices grouped by cell, with their position at hand */
} PixelIndex;

static void pixel_index_free(PixelIndex *pi)
{
    free(pi->start);
    free(pi->items);
}

static size_t cell_of(const PixelIndex *pi, IPt p)
{
    return (size_t) (p.y / pi->side) * pi->ncx + (size_t) (p.x / pi->side);
}

static bool pixel_index_build(const Graph *g, PixelIndex *pi)
{
    memset(pi, 0, sizeof *pi);
    i64 top = 0;
    for (size_t i = 0; i < g->hv.n; i++)
        top = imax(top, imax(g->hv.v[i].p.x, g->hv.v[i].p.y));
    pi->side = (i64) ceil((double) top / sqrt(4.0 * ((double) g->hv.n + 1)));
    if (pi->side < 1)
        pi->side = 1;
    pi->ncx = (size_t) (top / pi->side) + 1;
    size_t ncells = pi->ncx * pi->ncx;
    pi->start = calloc(ncells + 1, sizeof(size_t));
    pi->items = malloc((g->hv.n ? g->hv.n : 1) * sizeof(PixelItem));
    size_t *fill = malloc((ncells + 1) * sizeof(size_t));
    if (pi->start == NULL || pi->items == NULL || fill == NULL) {
        free(fill);
        pixel_index_free(pi);
        return false;
    }
    for (size_t i = 0; i < g->hv.n; i++)
        pi->start[cell_of(pi, g->hv.v[i].p) + 1]++;
    for (size_t c = 0; c < ncells; c++)
        pi->start[c + 1] += pi->start[c];
    memcpy(fill, pi->start, (ncells + 1) * sizeof(size_t));
    for (size_t i = 0; i < g->hv.n; i++)
    {
        PixelItem item = {g->hv.v[i].p, (uint32_t) i};
        pi->items[fill[cell_of(pi, item.p)]++] = item;
    }
    free(fill);
    return true;
}

/* Collect the hot pixels, other than the two end vertices, that the segment
   touches. Candidates are the pixels whose centre lies in the segment's
   bounding box and inside the cells along the segment (a margin of 1.5 steps
   absorbs the rounding of the double arithmetic used only to pick cells). */
static bool collect_hits(Graph *g, const PixelIndex *pi, const Seg *seg, uint32_t idp,
                         uint32_t idq, VecHit *hits)
{
    i64 xmin = imin(seg->p.x, seg->q.x), xmax = imax(seg->p.x, seg->q.x);
    i64 ymin = imin(seg->p.y, seg->q.y), ymax = imax(seg->p.y, seg->q.y);
    double dx = (double) (seg->q.x - seg->p.x), dy = (double) (seg->q.y - seg->p.y);
    for (i64 col = xmin / pi->side; col <= xmax / pi->side; col++) {
        i64 rlo = ymin, rhi = ymax;
        if (dx != 0) {
            double xa = fmax((double) (col * pi->side) - 0.5, (double) xmin);
            double xb = fmin((double) (col * pi->side + pi->side - 1) + 0.5, (double) xmax);
            double ya = (double) seg->p.y + (xa - (double) seg->p.x) * dy / dx;
            double yb = (double) seg->p.y + (xb - (double) seg->p.x) * dy / dx;
            rlo = imax(ymin, (i64) floor(fmin(ya, yb) - 1.5));
            rhi = imin(ymax, (i64) ceil(fmax(ya, yb) + 1.5));
        }
        for (i64 row = rlo / pi->side; row <= rhi / pi->side; row++) {
            size_t cell = (size_t) row * pi->ncx + (size_t) col;
            for (size_t k = pi->start[cell]; k < pi->start[cell + 1]; k++) {
                uint32_t i = pi->items[k].id;
                IPt c = pi->items[k].p;
                g->work++;
                if (c.x < xmin || c.x > xmax || c.y < ymin || c.y > ymax || i == idp || i == idq)
                    continue;
                if (!pixel_touched(seg->p, seg->q, c))
                    continue;
                Hit h = {(i128) (c.x - seg->p.x) * (seg->q.x - seg->p.x) +
                             (i128) (c.y - seg->p.y) * (seg->q.y - seg->p.y),
                         i};
                if (!VPUSH(*hits, h))
                    return false;
            }
        }
    }
    return true;
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

    PixelIndex pi;
    if (!pixel_index_build(g, &pi))
        return CGPBStatusNoMemory;
    VecHit hits = {0};
    for (size_t s = 0; s < g->segs.n; s++) {
        const Seg *seg = &g->segs.v[s];
        uint32_t idp, idq;
        if (!pb_find_vertex(g, seg->p, &idp) || !pb_find_vertex(g, seg->q, &idq)) {
            st = CGPBStatusInconsistent;
            break;
        }
        if (!VPUSH(g->off, g->ids.n)) {
            st = CGPBStatusNoMemory;
            break;
        }
        hits.n = 0;
        if (!collect_hits(g, &pi, seg, idp, idq, &hits)) {
            st = CGPBStatusNoMemory;
            break;
        }
        if (g->work > PB_WORK_LIMIT) {
            st = CGPBStatusTooComplex;
            break;
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
            st = CGPBStatusNoMemory;
            break;
        }
        g->work += hits.n;
        if (g->ids.n > PB_MAX_CHAIN_IDS) {
            st = CGPBStatusTooComplex;
            break;
        }
    }
    VFREE(hits);
    pixel_index_free(&pi);
    if (st != CGPBStatusOK)
        return st;
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
            e.d[g->segs.v[s].src] = sign * g->segs.v[s].w;
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
            continue;
        }
        g->edges.v[out++] = *e;
    }
    size_t keep = 0;
    for (size_t i = 0; i < out; i++) {
        const Edge *e = &g->edges.v[i];
        if (e->d[0] == 0 && e->d[1] == 0)
            continue;
        g->edges.v[keep++] = *e;
    }
    g->edges.n = keep;
    return CGPBStatusOK;
}

CGPBStatus pb_build_graph(Graph *g, const InputSet *sets, size_t nsets)
{
    CGPBStatus st = pb_grid_init(&g->grid, sets, nsets);
    if (st != CGPBStatusOK)
        return st;
    VecHV tmp = {0};
    for (size_t s = 0; s < nsets && st == CGPBStatusOK; s++) {
        for (size_t i = 0; i < sets[s].count && st == CGPBStatusOK; i++) {
            const CGPBContour *c = &sets[s].list[i];
            st = pb_add_contour(g, &tmp, c, sets[s].src);
        }
    }
    VFREE(tmp);
    if (st == CGPBStatusOK) {
        dedupe_region_segments(g);
        st = node_segments(g);
    }
    if (st == CGPBStatusOK)
        st = build_edges(g);
    if (st == CGPBStatusOK)
        st = pb_label_edges(g);
    return st;
}
