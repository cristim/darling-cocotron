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

// A TextKit 2 layout fragment (macOS 12), declared as the public documentation spells it. No layout manager in this
// tree produces layout fragments, so a fragment made with -initWithTextElement:range: never leaves the
// NSTextLayoutFragmentStateNone state; see UIFoundation/NSTextLayoutFragment.m.

#import <AppKit/AppKitExport.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class NSTextElement, NSTextRange, NSTextLayoutManager, NSTextLineFragment, NSTextAttachmentViewProvider;
@protocol NSTextLocation;

// GUESS (not in the public documentation, not observed): the raw values, in the order none, estimated, calculated,
// layoutAvailable (the documentation lists the cases alphabetically and gives no values).
typedef NS_ENUM(NSUInteger, NSTextLayoutFragmentState) {
    NSTextLayoutFragmentStateNone = 0,
    NSTextLayoutFragmentStateEstimatedUsageBounds = 1,
    NSTextLayoutFragmentStateCalculatedUsageBounds = 2,
    NSTextLayoutFragmentStateLayoutAvailable = 3,
};

// GUESS (not in the public documentation, not observed): the raw values (the documentation names the four options
// and gives no values).
typedef NS_OPTIONS(NSUInteger, NSTextLayoutFragmentEnumerationOptions) {
    NSTextLayoutFragmentEnumerationOptionsNone = 0,
    NSTextLayoutFragmentEnumerationOptionsReverse = (1 << 0),
    NSTextLayoutFragmentEnumerationOptionsEnsuresLayout = (1 << 1),
    NSTextLayoutFragmentEnumerationOptionsEstimatesSize = (1 << 2),
    NSTextLayoutFragmentEnumerationOptionsEnsuresExtraLineFragment = (1 << 3),
};

@interface NSTextLayoutFragment : NSObject

- (nullable instancetype) initWithCoder: (NSCoder *) coder;
- (instancetype) initWithTextElement: (NSTextElement *) textElement range: (nullable NSTextRange *) rangeInElement;

@property(readonly, weak, nullable) NSTextLayoutManager *textLayoutManager;
@property(readonly, weak) NSTextElement *textElement;
@property(readonly, strong) NSTextRange *rangeInElement;
@property(readonly) NSTextLayoutFragmentState state;
@property(strong, nullable) NSOperationQueue *layoutQueue;

@property(readonly, copy) NSArray<NSTextLineFragment *> *textLineFragments;
- (nullable NSTextLineFragment *) textLineFragmentForTextLocation: (id<NSTextLocation>) textLocation
                                               isUpstreamAffinity: (BOOL) isUpstreamAffinity;
- (nullable NSTextLineFragment *) textLineFragmentForVerticalOffset: (CGFloat) verticalOffset
                                                 requiresExactMatch: (BOOL) requiresExactMatch;

@property(readonly) CGRect layoutFragmentFrame;
@property(readonly) CGRect renderingSurfaceBounds;
@property(readonly) CGFloat leadingPadding;
@property(readonly) CGFloat trailingPadding;
@property(readonly) CGFloat topMargin;
@property(readonly) CGFloat bottomMargin;

@property(readonly, copy) NSArray<NSTextAttachmentViewProvider *> *textAttachmentViewProviders;
- (CGRect) frameForTextAttachmentAtLocation: (id<NSTextLocation>) location;

- (void) invalidateLayout;
- (void) drawAtPoint: (CGPoint) point inContext: (CGContextRef) context;

@end
