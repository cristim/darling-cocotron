/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CGDirectDisplay.h>
#include <CoreGraphics/CGGeometry.h>
#include <stdio.h>

typedef float CGGammaValue;
typedef int32_t CGWindowLevel;

static int verbose = 0;

__attribute__((constructor)) static void initme(void) {
    verbose = getenv("STUB_VERBOSE") != NULL;
}

boolean_t CGCursorIsVisible(void) {
    if(verbose)
        puts("STUB: CGCursorIsVisible called");
    return false;
}

CGOpenGLDisplayMask CGDisplayIDToOpenGLDisplayMask(CGDirectDisplayID a) {
    if(verbose)
        puts("STUB: CGDisplayIDToOpenGLDisplayMask called");
    return 0;
}

void CGDisplayRestoreColorSyncSettings(void) {
    if(verbose)
        puts("STUB: CGDisplayRestoreColorSyncSettings called");
}

CGError CGGetDisplayTransferByFormula(CGDirectDisplayID a, CGGammaValue *b, CGGammaValue *c, CGGammaValue *d, CGGammaValue *e, CGGammaValue *f, CGGammaValue *g, CGGammaValue *h, CGGammaValue *i, CGGammaValue *j) {
    if(verbose)
        puts("STUB: CGGetDisplayTransferByFormula called");
    return (CGError)0;
}

CGError CGGetDisplayTransferByTable(CGDirectDisplayID a, uint32_t b, CGGammaValue *c, CGGammaValue *d, CGGammaValue *e, uint32_t *f) {
    if(verbose)
        puts("STUB: CGGetDisplayTransferByTable called");
    return (CGError)0;
}

void CGGetLastMouseDelta(int32_t *a, int32_t *b) {
    if(verbose)
        puts("STUB: CGGetLastMouseDelta called");
}

CGError CGSetDisplayTransferByFormula(CGDirectDisplayID a, CGGammaValue b, CGGammaValue c, CGGammaValue d, CGGammaValue e, CGGammaValue f, CGGammaValue g, CGGammaValue h, CGGammaValue i, CGGammaValue j) {
    if(verbose)
        puts("STUB: CGSetDisplayTransferByFormula called");
    return (CGError)0;
}

CGError CGSetDisplayTransferByTable(CGDirectDisplayID a, uint32_t b, const CGGammaValue *c, const CGGammaValue *d, const CGGammaValue *e) {
    if(verbose)
        puts("STUB: CGSetDisplayTransferByTable called");
    return (CGError)0;
}

CGError CGSetLocalEventsSuppressionInterval(CFTimeInterval a) {
    if(verbose)
        puts("STUB: CGSetLocalEventsSuppressionInterval called");
    return (CGError)0;
}

CGWindowLevel CGShieldingWindowLevel(void) {
    if(verbose)
        puts("STUB: CGShieldingWindowLevel called");
    return 0;
}

void* CGColorSpaceGetBaseColorSpace(void* space) {
    return NULL;
}

void CGColorSpaceGetColorTable(void* space, uint8_t *table) {
}

size_t CGColorSpaceGetColorTableCount(void* space) {
    return 0;
}

void CGPathAddRelativeArc(void* path, const void *m, CGFloat x, CGFloat y, CGFloat radius, CGFloat startAngle, CGFloat delta) {
}

void* CGPathCreateCopyByDashingPath(void* path, const void *m, CGFloat phase, const CGFloat *lengths, size_t count) {
    return NULL;
}

void CGRectDivide(CGRect rect, CGRect *slice, CGRect *remainder, CGFloat amount, CGRectEdge edge) {
    if (slice == NULL && remainder == NULL) return;
    if (amount < 0) amount = 0;
    CGRect s = rect;
    CGRect r = rect;
    switch (edge) {
        case CGRectMinXEdge:
            if (amount > rect.size.width) amount = rect.size.width;
            s.size.width = amount;
            r.origin.x += amount;
            r.size.width -= amount;
            break;
        case CGRectMaxXEdge:
            if (amount > rect.size.width) amount = rect.size.width;
            s.origin.x = rect.origin.x + rect.size.width - amount;
            s.size.width = amount;
            r.size.width -= amount;
            break;
        case CGRectMinYEdge:
            if (amount > rect.size.height) amount = rect.size.height;
            s.size.height = amount;
            r.origin.y += amount;
            r.size.height -= amount;
            break;
        case CGRectMaxYEdge:
            if (amount > rect.size.height) amount = rect.size.height;
            s.origin.y = rect.origin.y + rect.size.height - amount;
            s.size.height = amount;
            r.size.height -= amount;
            break;
    }
    if (slice) *slice = s;
    if (remainder) *remainder = r;
}

// A style is only a handle here: CGStyleCreateShadow drops its parameters and
// CGContextSetStyle ignores the style. The handle is reference counted so that
// CGStyleRetain and CGStyleRelease balance.
typedef struct {
    int32_t retainCount;
} CGStyleStub;

void *CGStyleCreateShadow(void *parameters, void *unused) {
    CGStyleStub *style = calloc(1, 8);
    if (style != NULL)
        style->retainCount = 1;
    return style;
}

void CGContextSetStyle(void *context, void *style) {
}

void *CGStyleRetain(void *style) {
    if (style != NULL)
        __atomic_add_fetch(&((CGStyleStub *)style)->retainCount, 1, __ATOMIC_RELAXED);
    return style;
}

// GUESS: styles compare by identity, because the handle holds no content to compare.
bool CGStyleEqualToStyle(void *style1, void *style2) {
    return style1 == style2;
}

void CGStyleRelease(void *style) {
    if (style != NULL &&
        __atomic_sub_fetch(&((CGStyleStub *)style)->retainCount, 1, __ATOMIC_ACQ_REL) == 0)
        free(style);
}
