#ifndef CGPATHBOOLEANINTERNAL_H
#define CGPATHBOOLEANINTERNAL_H

/* Internal types and helpers shared by the CGPathBoolean*.c files. */

#include "CGPathBoolean.h"

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef int64_t i64;
typedef __int128 i128;

typedef struct {
    i64 x, y;
} IPt;

#define GRID_BITS 40

#define VEC(T)                                                                 \
    struct {                                                                   \
        T *v;                                                                  \
        size_t n, cap;                                                         \
    }

static inline bool vgrow(void **v, size_t *cap, size_t n, size_t size)
{
    if (n < *cap)
        return true;
    size_t newCap = *cap ? *cap * 2 : 16;
    void *p = realloc(*v, newCap * size);
    if (p == NULL)
        return false;
    *v = p;
    *cap = newCap;
    return true;
}

#define VPUSH(vec, val)                                                        \
    (vgrow((void **) &(vec).v, &(vec).cap, (vec).n, sizeof(*(vec).v))          \
         ? ((vec).v[(vec).n++] = (val), true)                                  \
         : false)

#define VFREE(vec)                                                             \
    do {                                                                       \
        free((vec).v);                                                         \
        (vec).v = NULL;                                                        \
        (vec).n = (vec).cap = 0;                                               \
    } while (0)

static inline i128 orient(IPt a, IPt b, IPt c)
{
    return (i128) (b.x - a.x) * (c.y - a.y) - (i128) (b.y - a.y) * (c.x - a.x);
}

static inline int sgn(i128 v)
{
    return (v > 0) - (v < 0);
}

static inline i128 floor_div(i128 a, i128 b) /* b > 0 */
{
    i128 q = a / b;
    if ((a % b) < 0)
        q--;
    return q;
}

static inline i128 round_div(i128 n, i128 d)
{
    if (d < 0) {
        n = -n;
        d = -d;
    }
    return floor_div(2 * n + d, 2 * d);
}

static inline bool ipt_eq(IPt a, IPt b)
{
    return a.x == b.x && a.y == b.y;
}

static inline int ipt_cmp(IPt a, IPt b)
{
    if (a.x != b.x)
        return a.x < b.x ? -1 : 1;
    if (a.y != b.y)
        return a.y < b.y ? -1 : 1;
    return 0;
}


/* ---- grid -------------------------------------------------------------- */

typedef struct {
    double ox, oy;
    int shift; /* grid coordinate = (x - ox) * 2^shift */
} Grid;

static inline IPt grid_snap(const Grid *g, double x, double y)
{
    IPt r;
    r.x = (i64) nearbyint(ldexp(x - g->ox, g->shift));
    r.y = (i64) nearbyint(ldexp(y - g->oy, g->shift));
    return r;
}

static inline void grid_unsnap(const Grid *g, IPt p, double *x, double *y)
{
    *x = g->ox + ldexp((double) p.x, -g->shift);
    *y = g->oy + ldexp((double) p.y, -g->shift);
}

/* ---- graph ------------------------------------------------------------- */

typedef struct {
    IPt p;
    double x, y; /* output coordinates: the input double when a vertex came from
                    the input, else the rounded crossing point */
    int orig;
} HV;

/* Segments are stored with p before q (x, then y) and a signed weight: +1
   when the input ran p to q, -1 when it ran q to p; equal segments of one set
   are merged and their weights added. */
typedef struct {
    IPt p, q;
    uint8_t src; /* 0: region set A, 1: region set B */
    int w;
} Seg;

typedef struct {
    uint32_t a, b; /* vertex ids, a < b: left to right, vertical edges upward */
    int d[2];      /* signed winding contribution per region set */
    int wl[2], wr[2]; /* winding on the left and right of a -> b */
} Edge;

typedef struct {
    i128 key;
    uint32_t id;
} Hit;

typedef VEC(HV) VecHV;
typedef VEC(uint32_t) VecU32;

typedef struct {
    Grid grid;
    VecHV hv; /* unique, sorted by position after build */
    VEC(Seg) segs;
    VEC(size_t) off;
    VecU32 ids;
    VEC(Edge) edges;
    uint64_t work;    /* costly steps (segment tests, pixel tests) so far, against PB_WORK_LIMIT */
    uint64_t cheap;   /* sweep-line moves and scans, about 16 times cheaper each (PB_CHEAP_SHIFT) */
} Graph;

/* Hard limits, so a pathological path fails loudly (CGPBStatusTooComplex)
   instead of hanging the caller or using unbounded memory (the hot pixels
   and the vertices on the segments, 2^23 in all, bound the edge array to
   about 300 MB). The work limit counts costly steps (segment and pixel tests)
   one each and the sweep-line moves of the labelling a sixteenth each, which
   is about their relative cost. Measured on the host at -O2:
   - a star polygon of 1600 points (1.3 million crossings, 640000 result
     rings) completes in 5 s; 1800 and 2000 points stop at the work limit
     after 6.5 s; 2200 points and up stop at the crossing limit in 0.1 s;
   - 200000 collinear input vertices under 100, 1000, 10000, 40000 or 80000
     long triangles stop after 0.6, 2.6, 6.1, 6.1 and 6.0 s (25 to 48 s with
     the former limit of 2^33);
   - 16000 identical squares take 0.01 s.
   The longest a stopped or finished operation took in these runs is 6.5 s. */
#ifndef PB_MAX_HOT_PIXELS
#define PB_MAX_HOT_PIXELS ((size_t) 1 << 21)
#endif
#ifndef PB_MAX_CHAIN_IDS
#define PB_MAX_CHAIN_IDS ((size_t) 1 << 23)
#endif
#ifndef PB_WORK_LIMIT
#define PB_WORK_LIMIT ((uint64_t) 1 << 30)
#endif
#define PB_CHEAP_SHIFT 4

typedef struct {
    const CGPBContour *list;
    size_t count;
    uint8_t src;
} InputSet;

static inline i64 imin(i64 a, i64 b) { return a < b ? a : b; }
static inline i64 imax(i64 a, i64 b) { return a > b ? a : b; }

/* qsort has no context argument and these run on any thread, so sort
   self-contained keyed records instead of indices into shared state. */
typedef struct {
    i64 key;
    size_t idx;
    const void *ptr;
} Keyed;

static inline int keyed_cmp(const void *pa, const void *pb)
{
    const Keyed *a = pa, *b = pb;
    return a->key < b->key ? -1 : a->key > b->key;
}

static inline bool pb_in_rule(bool evenOdd, int w)
{
    return evenOdd ? (w & 1) != 0 : w != 0;
}

static inline IPt vp(const Graph *g, uint32_t id)
{
    return g->hv.v[id].p;
}

static inline i128 cross2(IPt a, IPt b)
{
    return (i128) a.x * b.y - (i128) a.y * b.x;
}

typedef struct {
    VecU32 ids;
    bool hole;
    i128 area2;
} IRing;

typedef VEC(IRing) VecIRing;
typedef VEC(CGPBRing) VecRing;

typedef struct {
    uint32_t from, to;
    uint8_t used;
} DEdge;

/* Node.c */
void pb_graph_free(Graph *g);
bool pb_find_vertex(const Graph *g, IPt p, uint32_t *id);
CGPBStatus pb_build_graph(Graph *g, const InputSet *sets, size_t nsets);
/* Label.c */
CGPBStatus pb_label_edges(Graph *g);
/* Rings.c */
void pb_iring_free(IRing *r);
bool pb_ring_simplify(const Graph *g, VecU32 *ids);
bool pb_ring_contains_point2(const Graph *g, const IRing *r, IPt p2);
CGPBStatus pb_trace_rings(const Graph *g, const DEdge *de_in, size_t nde, VecIRing *rings);
bool pb_result_push(VecRing *out, const Graph *g, const uint32_t *ids, size_t n, bool closed,
                    bool hole, size_t group);
CGPBStatus pb_finish(VecRing *out, CGPBStatus st, CGPBResult *result);

#endif
