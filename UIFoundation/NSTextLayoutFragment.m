/*
 This file is part of Darling.

 Copyright (C) 2026 Darling developers

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

#import "UIFAppKit.h"
#import <AppKit/NSTextAttachment.h>
#import <AppKit/NSTextElement.h>
#import <AppKit/NSTextLayoutFragment.h>
#import <AppKit/NSTextLineFragment.h>
#import <AppKit/NSTextRange.h>

// No layout manager in this tree produces layout fragments, so a fragment never leaves the "none" state: the public
// documentation says line fragments, frames and attachment frames are valid only once layout is available, and
// each property below answers what the documentation gives for an unlaid-out fragment (empty arrays, nil, zero
// rectangles; -frameForTextAttachmentAtLocation: is documented to answer CGRectZero in that state).
//
// GUESS (not in the public documentation, not observed): margins and paddings are 0 before layout; a nil range of
// -initWithTextElement:range: means the element's whole range (-elementRange); -invalidateLayout has nothing to
// invalidate; -drawAtPoint:inContext: draws nothing because nothing is laid out. -initWithCoder: fails loudly: the
// archive format of a layout fragment is not documented and nothing here writes one.
@implementation NSTextLayoutFragment {
    NSTextElement *_textElement; // weak in Apple's header; not retained here, like NSTextKit2.m
    NSTextRange *_rangeInElement;
    NSOperationQueue *_layoutQueue;
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    [self release];
    [NSException raise: NSInvalidArgumentException
                format: @"-[NSTextLayoutFragment initWithCoder:] is not implemented: this tree has no text layout fragment archive"];
    return nil;
}

- (instancetype) initWithTextElement: (NSTextElement *) textElement range: (NSTextRange *) rangeInElement {
    if ((self = [super init])) {
        _textElement = textElement;
        _rangeInElement = [(rangeInElement ?: [textElement elementRange]) retain];
    }
    return self;
}

- (void) dealloc {
    [_rangeInElement release];
    [_layoutQueue release];
    [super dealloc];
}

- (NSTextLayoutManager *) textLayoutManager {
    return nil;
}

- (NSTextElement *) textElement {
    return _textElement;
}

- (NSTextRange *) rangeInElement {
    return _rangeInElement;
}

- (NSTextLayoutFragmentState) state {
    return NSTextLayoutFragmentStateNone;
}

- (NSOperationQueue *) layoutQueue {
    return _layoutQueue;
}

- (void) setLayoutQueue: (NSOperationQueue *) queue {
    [queue retain];
    [_layoutQueue release];
    _layoutQueue = queue;
}

- (NSArray *) textLineFragments {
    return [NSArray array];
}

- (NSTextLineFragment *) textLineFragmentForTextLocation: (id<NSTextLocation>) textLocation
                                      isUpstreamAffinity: (BOOL) isUpstreamAffinity
{
    return nil;
}

- (NSTextLineFragment *) textLineFragmentForVerticalOffset: (CGFloat) verticalOffset
                                        requiresExactMatch: (BOOL) requiresExactMatch
{
    return nil;
}

- (CGRect) layoutFragmentFrame {
    return CGRectZero;
}

- (CGRect) renderingSurfaceBounds {
    return CGRectZero;
}

- (CGFloat) leadingPadding {
    return 0;
}

- (CGFloat) trailingPadding {
    return 0;
}

- (CGFloat) topMargin {
    return 0;
}

- (CGFloat) bottomMargin {
    return 0;
}

- (NSArray *) textAttachmentViewProviders {
    return [NSArray array];
}

- (CGRect) frameForTextAttachmentAtLocation: (id<NSTextLocation>) location {
    return CGRectZero;
}

- (void) invalidateLayout {
}

- (void) drawAtPoint: (CGPoint) point inContext: (CGContextRef) context {
}

@end
