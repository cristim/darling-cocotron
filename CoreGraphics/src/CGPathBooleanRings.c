/* Tracing boundary edges into rings, ring cleanup and result records. */

#include "CGPathBooleanInternal.h"

void pb_iring_free(IRing *r)
{
    VFREE(r->ids);
}

static int cw_class(IPt r, IPt d)
{
    i128 c = cross2(r, d);
    if (c < 0)
        return 0;
    if (c > 0)
        return 2;
    i128 dot = (i128) r.x * d.x + (i128) r.y * d.y;
    return dot < 0 ? 1 : 3;
}

/* is d1 reached before d2 when rotating clockwise from r? */
static bool cw_less(IPt r, IPt d1, IPt d2)
{
    int c1 = cw_class(r, d1), c2 = cw_class(r, d2);
    if (c1 != c2)
        return c1 < c2;
    if (c1 == 1 || c1 == 3)
        return false;
    return cross2(d1, d2) < 0;
}

static bool collinear_forward(IPt prev, IPt cur, IPt next)
{
    i128 dot = (i128) (cur.x - prev.x) * (next.x - cur.x) +
               (i128) (cur.y - prev.y) * (next.y - cur.y);
    return orient(prev, cur, next) == 0 && dot > 0;
}

/* Drop vertices that lie on the straight line between their neighbours. A
   closed ring whose vertices are all collinear collapses to nothing. */
bool pb_ring_simplify(const Graph *g, VecU32 *ids, bool closed)
{
    size_t n = ids->n;
    if (n < (closed ? 3 : 2))
        return true;
    uint32_t *tmp = malloc(n * sizeof(uint32_t));
    if (tmp == NULL)
        return false;
    size_t out = 0;
    if (closed) {
        size_t c = n;
        for (size_t i = 0; i < n && c == n; i++)
            if (!collinear_forward(vp(g, ids->v[(i + n - 1) % n]), vp(g, ids->v[i]),
                                   vp(g, ids->v[(i + 1) % n])))
                c = i;
        if (c == n) {
            ids->n = 0;
            free(tmp);
            return true;
        }
        tmp[out++] = ids->v[c];
        for (size_t k = 1; k < n; k++) {
            size_t i = (c + k) % n;
            if (!collinear_forward(vp(g, tmp[out - 1]), vp(g, ids->v[i]),
                                   vp(g, ids->v[(i + 1) % n])))
                tmp[out++] = ids->v[i];
        }
    } else {
        tmp[out++] = ids->v[0];
        for (size_t i = 1; i + 1 < n; i++)
            if (!collinear_forward(vp(g, tmp[out - 1]), vp(g, ids->v[i]),
                                   vp(g, ids->v[i + 1])))
                tmp[out++] = ids->v[i];
        tmp[out++] = ids->v[n - 1];
    }
    memcpy(ids->v, tmp, out * sizeof(uint32_t));
    ids->n = out;
    free(tmp);
    return true;
}

bool pb_ring_contains_point2(const Graph *g, const IRing *r, IPt p2)
{
    bool inside = false;
    size_t n = r->ids.n;
    for (size_t i = 0; i < n; i++) {
        IPt a = vp(g, r->ids.v[i]), b = vp(g, r->ids.v[(i + 1) % n]);
        IPt a2 = {2 * a.x, 2 * a.y}, b2 = {2 * b.x, 2 * b.y};
        if ((a2.y <= p2.y) == (b2.y <= p2.y))
            continue;
        int s = sgn(orient(a2, b2, p2));
        if ((b2.y > a2.y && s > 0) || (b2.y < a2.y && s < 0))
            inside = !inside;
    }
    return inside;
}

CGPBStatus pb_trace_rings(const Graph *g, const DEdge *de_in, size_t nde,
                              VecIRing *rings)
{
    DEdge *de = malloc((nde ? nde : 1) * sizeof(DEdge));
    size_t *ostart = calloc(g->hv.n + 2, sizeof(size_t));
    size_t *oidx = malloc((nde ? nde : 1) * sizeof(size_t));
    CGPBStatus st = CGPBStatusOK;
    if (de == NULL || ostart == NULL || oidx == NULL) {
        st = CGPBStatusNoMemory;
        goto done;
    }
    if (nde > 0)
        memcpy(de, de_in, nde * sizeof(DEdge));
    for (size_t i = 0; i < nde; i++)
        ostart[de[i].from + 1]++;
    for (size_t v = 0; v <= g->hv.n; v++)
        ostart[v + 1] += ostart[v];
    {
        size_t *fill = malloc((g->hv.n + 1) * sizeof(size_t));
        if (fill == NULL) {
            st = CGPBStatusNoMemory;
            goto done;
        }
        memcpy(fill, ostart, (g->hv.n + 1) * sizeof(size_t));
        for (size_t i = 0; i < nde; i++)
            oidx[fill[de[i].from]++] = i;
        free(fill);
    }

    for (size_t i = 0; i < nde; i++) {
        if (de[i].used)
            continue;
        IRing ring;
        memset(&ring, 0, sizeof ring);
        size_t cur = i;
        bool failed = false;
        for (;;) {
            de[cur].used = 1;
            if (!VPUSH(ring.ids, de[cur].from)) {
                st = CGPBStatusNoMemory;
                break;
            }
            uint32_t v = de[cur].to;
            IPt r = {vp(g, de[cur].from).x - vp(g, v).x,
                     vp(g, de[cur].from).y - vp(g, v).y};
            size_t best = (size_t) -1;
            IPt bestd = {0, 0};
            for (size_t k = ostart[v]; k < ostart[v + 1]; k++) {
                size_t cand = oidx[k];
                if (de[cand].used && cand != i)
                    continue;
                IPt d = {vp(g, de[cand].to).x - vp(g, v).x,
                         vp(g, de[cand].to).y - vp(g, v).y};
                if (best == (size_t) -1 || cw_less(r, d, bestd)) {
                    best = cand;
                    bestd = d;
                }
            }
            if (best == (size_t) -1) {
                failed = true;
                break;
            }
            if (best == i)
                break; /* the pairing at this vertex leads back to the first edge */
            cur = best;
        }
        if (st != CGPBStatusOK || failed) {
            pb_iring_free(&ring);
            if (st == CGPBStatusOK)
                st = CGPBStatusInconsistent;
            break;
        }
        if (!pb_ring_simplify(g, &ring.ids, true)) {
            pb_iring_free(&ring);
            st = CGPBStatusNoMemory;
            break;
        }
        if (ring.ids.n < 3) {
            pb_iring_free(&ring);
            continue;
        }
        i128 area2 = 0;
        for (size_t k = 0; k < ring.ids.n; k++)
            area2 += cross2(vp(g, ring.ids.v[k]), vp(g, ring.ids.v[(k + 1) % ring.ids.n]));
        if (area2 == 0) {
            pb_iring_free(&ring);
            continue;
        }
        ring.area2 = area2;
        ring.hole = area2 < 0;
        if (!VPUSH(*rings, ring)) {
            pb_iring_free(&ring);
            st = CGPBStatusNoMemory;
            break;
        }
    }
done:
    free(de);
    free(ostart);
    free(oidx);
    return st;
}

static void pb_export_ring(const Graph *g, const uint32_t *ids, size_t n,
                        CGPBRing *out)
{
    for (size_t k = 0; k < n; k++) {
        const HV *v = &g->hv.v[ids[k]];
        out->points[k].x = v->x;
        out->points[k].y = v->y;
    }
    out->count = n;
}

void CGPBResultFree(CGPBResult *result)
{
    for (size_t i = 0; i < result->count; i++)
        free(result->rings[i].points);
    free(result->rings);
    result->rings = NULL;
    result->count = 0;
}

bool pb_result_push(VecRing *out, const Graph *g, const uint32_t *ids,
                        size_t n, bool closed, bool hole, size_t group)
{
    CGPBRing ring;
    ring.points = malloc((n ? n : 1) * sizeof(CGPBPoint));
    if (ring.points == NULL)
        return false;
    pb_export_ring(g, ids, n, &ring);
    ring.closed = closed;
    ring.hole = hole;
    ring.group = group;
    if (!VPUSH(*out, ring)) {
        free(ring.points);
        return false;
    }
    return true;
}

CGPBStatus pb_finish(VecRing *out, CGPBStatus st, CGPBResult *result)
{
    if (st != CGPBStatusOK) {
        for (size_t i = 0; i < out->n; i++)
            free(out->v[i].points);
        VFREE(*out);
        result->rings = NULL;
        result->count = 0;
        return st;
    }
    result->rings = out->v;
    result->count = out->n;
    return CGPBStatusOK;
}
