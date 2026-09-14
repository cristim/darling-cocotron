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

#import <AppKit/NSLayoutConstraint.h>
#import <AppKit/NSView.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSValue.h>

const CGFloat NSViewNoInstrinsicMetric = 0xbff0000000000000;
const CGFloat NSViewNoIntrinsicMetric = 0xbff0000000000000;

// "-" between two views, and between a view and its superview's edge.
static const CGFloat VFLStandardSiblingSpacing = 8;
static const CGFloat VFLStandardSuperviewSpacing = 20;

typedef struct {
    NSString *format;
    NSUInteger position;
    NSUInteger length;
    NSDictionary *metrics;
    NSDictionary *views;
} VFLParser;

typedef struct {
    NSLayoutRelation relation;
    CGFloat constant;
    id view;
    NSLayoutPriority priority;
} VFLPredicate;

static void vflFail(VFLParser *p, NSString *reason) {
    [NSException raise: NSInvalidArgumentException
                format: @"Unable to parse constraint format: %@ at index %lu of \"%@\"",
                        reason, (unsigned long) p->position, p->format];
}

static unichar vflPeek(VFLParser *p) {
    while (p->position < p->length &&
           [p->format characterAtIndex: p->position] == ' ')
        p->position++;
    return p->position < p->length ? [p->format characterAtIndex: p->position] : 0;
}

static void vflExpect(VFLParser *p, unichar c) {
    if (vflPeek(p) != c)
        vflFail(p, [NSString stringWithFormat: @"expected '%C'", c]);
    p->position++;
}

static BOOL vflIsNameStart(unichar c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

static NSString *vflName(VFLParser *p) {
    if (!vflIsNameStart(vflPeek(p)))
        vflFail(p, @"expected a name");
    NSUInteger start = p->position;
    while (p->position < p->length) {
        unichar c = [p->format characterAtIndex: p->position];
        if (!vflIsNameStart(c) && !(c >= '0' && c <= '9'))
            break;
        p->position++;
    }
    return [p->format substringWithRange: NSMakeRange(start, p->position - start)];
}

// A number (signed only inside parentheses, where '-' can't be a
// connection), a metric name or, when allowView, a view name.
static CGFloat vflValue(VFLParser *p, BOOL allowSign, BOOL allowView, id *view) {
    unichar c = vflPeek(p);
    if (vflIsNameStart(c)) {
        NSString *name = vflName(p);
        id metric = [p->metrics objectForKey: name];
        if (metric != nil)
            return [metric doubleValue];
        id namedView = allowView ? [p->views objectForKey: name] : nil;
        if (namedView == nil)
            vflFail(p, [NSString stringWithFormat: @"unknown metric or view \"%@\"", name]);
        *view = namedView;
        return 0;
    }
    NSUInteger start = p->position;
    if (allowSign && (c == '-' || c == '+'))
        p->position++;
    BOOL digits = NO;
    while (p->position < p->length) {
        c = [p->format characterAtIndex: p->position];
        if (c >= '0' && c <= '9')
            digits = YES;
        else if (c != '.')
            break;
        p->position++;
    }
    if (!digits)
        vflFail(p, @"expected a number or a metric");
    return [[p->format substringWithRange: NSMakeRange(start, p->position - start)] doubleValue];
}

// "(pred, pred)" or, without parentheses, a single number or metric. allowView
// marks the list inside a view's brackets, where predicates may name views.
static void vflPredicates(VFLParser *p, BOOL allowView, NSMutableData *out) {
    BOOL parens = vflPeek(p) == '(';
    if (parens)
        p->position++;
    for (;;) {
        VFLPredicate pred = {NSLayoutRelationEqual, 0, nil, NSLayoutPriorityRequired};
        unichar r = vflPeek(p);
        if (parens && (r == '=' || r == '<' || r == '>')) {
            if (p->position + 1 >= p->length ||
                [p->format characterAtIndex: p->position + 1] != '=')
                vflFail(p, @"expected ==, <= or >=");
            if (r == '<')
                pred.relation = NSLayoutRelationLessThanOrEqual;
            else if (r == '>')
                pred.relation = NSLayoutRelationGreaterThanOrEqual;
            p->position += 2;
        }
        pred.constant = vflValue(p, parens, allowView && parens, &pred.view);
        if (parens && vflPeek(p) == '@') {
            id unused = nil;
            p->position++;
            pred.priority = vflValue(p, NO, NO, &unused);
        }
        [out appendBytes: &pred length: sizeof(pred)];
        if (!parens || vflPeek(p) != ',')
            break;
        p->position++;
    }
    if (parens)
        vflExpect(p, ')');
}

// The spacing before the next view or edge: flush (none), standard ("-") or
// "-predicates-". Returns NO for a flush connection. afterEdge marks a
// connection that follows a leading '|'.
static BOOL vflConnection(VFLParser *p, BOOL afterEdge, NSMutableData *out) {
    [out setLength: 0];
    VFLPredicate pred = {NSLayoutRelationEqual, 0, nil, NSLayoutPriorityRequired};
    if (vflPeek(p) != '-') {
        [out appendBytes: &pred length: sizeof(pred)];
        return NO;
    }
    p->position++;
    unichar c = vflPeek(p);
    if (c == '[' || c == '|' || c == 0) {
        pred.constant = (afterEdge || c == '|') ? VFLStandardSuperviewSpacing
                                                : VFLStandardSiblingSpacing;
        [out appendBytes: &pred length: sizeof(pred)];
        return YES;
    }
    vflPredicates(p, NO, out);
    vflExpect(p, '-');
    return YES;
}

static void vflAdd(NSMutableArray *result, id item1, NSLayoutAttribute attr1,
                   const VFLPredicate *pred, id item2, NSLayoutAttribute attr2)
{
    NSLayoutConstraint *constraint =
            [NSLayoutConstraint constraintWithItem: item1
                                         attribute: attr1
                                         relatedBy: pred->relation
                                            toItem: item2
                                         attribute: attr2
                                        multiplier: 1
                                          constant: pred->constant];
    [constraint setPriority: pred->priority];
    [result addObject: constraint];
}

// One constraint per predicate that "later" is its spacing past "earlier" in
// reading order. Right to left, reading order runs against the x axis, so the
// items swap to keep the spacing positive.
static void vflAddSpacing(NSMutableArray *result, NSData *predicates, BOOL reversed,
                          id later, NSLayoutAttribute laterAttribute,
                          id earlier, NSLayoutAttribute earlierAttribute)
{
    const VFLPredicate *preds = [predicates bytes];
    for (NSUInteger i = 0; i < [predicates length] / sizeof(VFLPredicate); i++) {
        if (reversed)
            vflAdd(result, earlier, earlierAttribute, &preds[i], later, laterAttribute);
        else
            vflAdd(result, later, laterAttribute, &preds[i], earlier, earlierAttribute);
    }
}

@implementation NSLayoutConstraint (NSVisualFormat)

+ (NSArray *) constraintsWithVisualFormat: (NSString *) format
                                  options: (NSLayoutFormatOptions) options
                                  metrics: (NSDictionary *) metrics
                                    views: (NSDictionary *) views
{
    VFLParser p = {format, 0, [format length], metrics, views};
    NSMutableArray *result = [NSMutableArray array];
    NSMutableArray *orderedViews = [NSMutableArray array];
    NSMutableData *connection = [NSMutableData data];
    NSMutableData *sizes = [NSMutableData data];

    BOOL vertical = NO;
    if (vflPeek(&p) == 'V' || vflPeek(&p) == 'H') {
        vertical = [format characterAtIndex: p.position] == 'V';
        p.position++;
        vflExpect(&p, ':');
    }
    NSLayoutAttribute leading = NSLayoutAttributeLeading;
    NSLayoutAttribute trailing = NSLayoutAttributeTrailing;
    NSLayoutAttribute size = NSLayoutAttributeWidth;
    BOOL reversed = NO;
    if (vertical) {
        leading = NSLayoutAttributeTop;
        trailing = NSLayoutAttributeBottom;
        size = NSLayoutAttributeHeight;
    } else if ((options & NSLayoutFormatDirectionMask) == NSLayoutFormatDirectionLeftToRight) {
        leading = NSLayoutAttributeLeft;
        trailing = NSLayoutAttributeRight;
    } else if ((options & NSLayoutFormatDirectionMask) == NSLayoutFormatDirectionRightToLeft) {
        leading = NSLayoutAttributeRight;
        trailing = NSLayoutAttributeLeft;
        reversed = YES;
    }

    BOOL fromSuperview = vflPeek(&p) == '|';
    if (fromSuperview) {
        p.position++;
        vflConnection(&p, YES, connection);
    }

    for (;;) {
        vflExpect(&p, '[');
        NSString *name = vflName(&p);
        id view = [views objectForKey: name];
        if (view == nil)
            vflFail(&p, [NSString stringWithFormat: @"unknown view \"%@\"", name]);
        [sizes setLength: 0];
        if (vflPeek(&p) == '(')
            vflPredicates(&p, YES, sizes);
        vflExpect(&p, ']');

        const VFLPredicate *preds = [sizes bytes];
        for (NSUInteger i = 0; i < [sizes length] / sizeof(VFLPredicate); i++)
            vflAdd(result, view, size, &preds[i], preds[i].view,
                   preds[i].view ? size : NSLayoutAttributeNotAnAttribute);

        id previous = [orderedViews lastObject];
        if (previous != nil) {
            vflAddSpacing(result, connection, reversed, view, leading, previous, trailing);
        } else if (fromSuperview) {
            id superview = [view superview];
            if (superview == nil)
                vflFail(&p, @"'|' needs a view with a superview");
            vflAddSpacing(result, connection, reversed, view, leading, superview, leading);
        }
        [orderedViews addObject: view];

        BOOL spaced = vflConnection(&p, NO, connection);
        unichar c = vflPeek(&p);
        if (c == '[')
            continue;
        if (c == '|') {
            id superview = [view superview];
            if (superview == nil)
                vflFail(&p, @"'|' needs a view with a superview");
            p.position++;
            vflAddSpacing(result, connection, reversed, superview, trailing, view, trailing);
        } else if (spaced) {
            vflFail(&p, @"expected a view or '|' after a connection");
        }
        break;
    }
    if (vflPeek(&p) != 0)
        vflFail(&p, @"unexpected character");

    NSUInteger alignment = options & NSLayoutFormatAlignmentMask;
    VFLPredicate equal = {NSLayoutRelationEqual, 0, nil, NSLayoutPriorityRequired};
    for (NSLayoutAttribute attribute = NSLayoutAttributeLeft;
         attribute <= NSLayoutAttributeFirstBaseline; attribute++) {
        if (!(alignment & (1 << attribute)))
            continue;
        for (NSUInteger i = 1; i < [orderedViews count]; i++)
            vflAdd(result, [orderedViews objectAtIndex: i], attribute, &equal,
                   [orderedViews objectAtIndex: 0], attribute);
    }
    return result;
}

@end
