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

#import <AppKit/AppKitExport.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSLayoutConstraint.h>

@class NSDictionary;

typedef float NSLayoutPriority;

static const NSLayoutPriority NSLayoutPriorityRequired = 1000;
static const NSLayoutPriority NSLayoutPriorityDefaultHigh = 750;
static const NSLayoutPriority NSLayoutPriorityDefaultLow = 250;
static const NSLayoutPriority NSLayoutPriorityFittingSizeCompression = 50;

typedef NS_ENUM(NSInteger, NSLayoutRelation) {
	NSLayoutRelationLessThanOrEqual = -1,
	NSLayoutRelationEqual = 0,
	NSLayoutRelationGreaterThanOrEqual = 1,
};

typedef NS_ENUM(NSInteger, NSLayoutAttribute) {
	NSLayoutAttributeNotAnAttribute = 0,
	NSLayoutAttributeLeft = 1,
	NSLayoutAttributeRight,
	NSLayoutAttributeTop,
	NSLayoutAttributeBottom,
	NSLayoutAttributeLeading,
	NSLayoutAttributeTrailing,
	NSLayoutAttributeWidth,
	NSLayoutAttributeHeight,
	NSLayoutAttributeCenterX,
	NSLayoutAttributeCenterY,
	NSLayoutAttributeLastBaseline,
	NSLayoutAttributeBaseline = NSLayoutAttributeLastBaseline,
	NSLayoutAttributeFirstBaseline,
};

typedef NS_OPTIONS(NSUInteger, NSLayoutFormatOptions) {
	NSLayoutFormatAlignAllLeft = (1 << NSLayoutAttributeLeft),
	NSLayoutFormatAlignAllRight = (1 << NSLayoutAttributeRight),
	NSLayoutFormatAlignAllTop = (1 << NSLayoutAttributeTop),
	NSLayoutFormatAlignAllBottom = (1 << NSLayoutAttributeBottom),
	NSLayoutFormatAlignAllLeading = (1 << NSLayoutAttributeLeading),
	NSLayoutFormatAlignAllTrailing = (1 << NSLayoutAttributeTrailing),
	NSLayoutFormatAlignAllCenterX = (1 << NSLayoutAttributeCenterX),
	NSLayoutFormatAlignAllCenterY = (1 << NSLayoutAttributeCenterY),
	NSLayoutFormatAlignAllLastBaseline = (1 << NSLayoutAttributeLastBaseline),
	NSLayoutFormatAlignAllFirstBaseline = (1 << NSLayoutAttributeFirstBaseline),
	NSLayoutFormatAlignAllBaseline = NSLayoutFormatAlignAllLastBaseline,
	NSLayoutFormatAlignmentMask = 0xFFFF,
	NSLayoutFormatDirectionLeadingToTrailing = 0 << 16,
	NSLayoutFormatDirectionLeftToRight = 1 << 16,
	NSLayoutFormatDirectionRightToLeft = 2 << 16,
	NSLayoutFormatDirectionMask = 0x3 << 16,
};

// Darling stores and archives constraints but does not solve them.
@interface NSLayoutConstraint (NSLayoutConstraintAPI)
+ (instancetype) constraintWithItem: (id) view1
                          attribute: (NSLayoutAttribute) attr1
                          relatedBy: (NSLayoutRelation) relation
                             toItem: (id) view2
                          attribute: (NSLayoutAttribute) attr2
                         multiplier: (CGFloat) multiplier
                           constant: (CGFloat) c;
+ (void) activateConstraints: (NSArray *) constraints;
+ (void) deactivateConstraints: (NSArray *) constraints;
@property(readonly, assign) id firstItem;
@property(readonly, assign) id secondItem;
@property(readonly) NSLayoutAttribute firstAttribute;
@property(readonly) NSLayoutAttribute secondAttribute;
@property(readonly) NSLayoutRelation relation;
@property(readonly) CGFloat multiplier;
@property CGFloat constant;
@property NSLayoutPriority priority;
@property(copy) NSString *identifier;
@property(getter=isActive) BOOL active;
@property BOOL shouldBeArchived;
@end

@interface NSLayoutConstraint (NSVisualFormat)
// Parses the visual format language; raises NSInvalidArgumentException on a
// malformed format or an unknown view or metric name.
+ (NSArray *) constraintsWithVisualFormat: (NSString *) format
                                  options: (NSLayoutFormatOptions) options
                                  metrics: (NSDictionary *) metrics
                                    views: (NSDictionary *) views;
@end

typedef NS_ENUM(NSInteger, NSLayoutConstraintOrientation) {
	NSLayoutConstraintOrientationHorizontal = 0,
	NSLayoutConstraintOrientationVertical = 1,
};

APPKIT_EXPORT const CGFloat NSViewNoInstrinsicMetric;
APPKIT_EXPORT const CGFloat NSViewNoIntrinsicMetric;
