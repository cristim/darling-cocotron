/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

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

#import <AppKit/NSCollectionViewCompositionalLayout.h>

enum {
    DimensionFractionalWidth,
    DimensionFractionalHeight,
    DimensionAbsolute,
    DimensionEstimated,
};

@implementation NSCollectionLayoutDimension
@synthesize dimension = _dimension;

+ (instancetype) _dimensionWithKind: (NSInteger) kind value: (CGFloat) value {
    NSCollectionLayoutDimension *result = [[self alloc] init];
    result->_kind = kind;
    result->_dimension = value;
    return [result autorelease];
}

+ (instancetype) fractionalWidthDimension: (CGFloat) fraction {
    return [self _dimensionWithKind: DimensionFractionalWidth value: fraction];
}

+ (instancetype) fractionalHeightDimension: (CGFloat) fraction {
    return [self _dimensionWithKind: DimensionFractionalHeight value: fraction];
}

+ (instancetype) absoluteDimension: (CGFloat) absoluteDimension {
    return [self _dimensionWithKind: DimensionAbsolute value: absoluteDimension];
}

+ (instancetype) estimatedDimension: (CGFloat) estimatedDimension {
    return [self _dimensionWithKind: DimensionEstimated value: estimatedDimension];
}

- (BOOL) isFractionalWidth {
    return _kind == DimensionFractionalWidth;
}

- (BOOL) isFractionalHeight {
    return _kind == DimensionFractionalHeight;
}

- (BOOL) isAbsolute {
    return _kind == DimensionAbsolute;
}

- (BOOL) isEstimated {
    return _kind == DimensionEstimated;
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

@end

@implementation NSCollectionLayoutSize
@synthesize widthDimension = _widthDimension;
@synthesize heightDimension = _heightDimension;

+ (instancetype) sizeWithWidthDimension: (NSCollectionLayoutDimension *) width
                        heightDimension: (NSCollectionLayoutDimension *) height {
    NSCollectionLayoutSize *result = [[self alloc] init];
    result->_widthDimension = [width retain];
    result->_heightDimension = [height retain];
    return [result autorelease];
}

- (void) dealloc {
    [_widthDimension release];
    [_heightDimension release];
    [super dealloc];
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

@end

@implementation NSCollectionLayoutSpacing
@synthesize spacing = _spacing;

+ (instancetype) _spacingWithValue: (CGFloat) value flexible: (BOOL) flexible {
    NSCollectionLayoutSpacing *result = [[self alloc] init];
    result->_spacing = value;
    result->_flexible = flexible;
    return [result autorelease];
}

+ (instancetype) flexibleSpacing: (CGFloat) flexibleSpacing {
    return [self _spacingWithValue: flexibleSpacing flexible: YES];
}

+ (instancetype) fixedSpacing: (CGFloat) fixedSpacing {
    return [self _spacingWithValue: fixedSpacing flexible: NO];
}

- (BOOL) isFlexibleSpacing {
    return _flexible;
}

- (BOOL) isFixedSpacing {
    return !_flexible;
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

@end

@implementation NSCollectionLayoutEdgeSpacing
@synthesize leading = _leading;
@synthesize top = _top;
@synthesize trailing = _trailing;
@synthesize bottom = _bottom;

+ (instancetype) spacingForLeading: (NSCollectionLayoutSpacing *) leading
                               top: (NSCollectionLayoutSpacing *) top
                          trailing: (NSCollectionLayoutSpacing *) trailing
                            bottom: (NSCollectionLayoutSpacing *) bottom {
    NSCollectionLayoutEdgeSpacing *result = [[self alloc] init];
    result->_leading = [leading retain];
    result->_top = [top retain];
    result->_trailing = [trailing retain];
    result->_bottom = [bottom retain];
    return [result autorelease];
}

- (void) dealloc {
    [_leading release];
    [_top release];
    [_trailing release];
    [_bottom release];
    [super dealloc];
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

@end

@implementation NSCollectionLayoutAnchor
@synthesize edges = _edges;
@synthesize offset = _offset;

+ (instancetype) _anchorWithEdges: (NSDirectionalRectEdge) edges
                           offset: (NSPoint) offset
                       fractional: (BOOL) fractional {
    NSCollectionLayoutAnchor *result = [[self alloc] init];
    result->_edges = edges;
    result->_offset = offset;
    result->_fractionalOffset = fractional;
    return [result autorelease];
}

+ (instancetype) layoutAnchorWithEdges: (NSDirectionalRectEdge) edges {
    return [self _anchorWithEdges: edges offset: NSZeroPoint fractional: NO];
}

+ (instancetype) layoutAnchorWithEdges: (NSDirectionalRectEdge) edges
                        absoluteOffset: (NSPoint) absoluteOffset {
    return [self _anchorWithEdges: edges offset: absoluteOffset fractional: NO];
}

+ (instancetype) layoutAnchorWithEdges: (NSDirectionalRectEdge) edges
                      fractionalOffset: (NSPoint) fractionalOffset {
    return [self _anchorWithEdges: edges offset: fractionalOffset fractional: YES];
}

- (BOOL) isAbsoluteOffset {
    return !_fractionalOffset && !NSEqualPoints(_offset, NSZeroPoint);
}

- (BOOL) isFractionalOffset {
    return _fractionalOffset;
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

@end

@implementation NSCollectionLayoutItem
@synthesize contentInsets = _contentInsets;
@synthesize edgeSpacing = _edgeSpacing;
@synthesize layoutSize = _layoutSize;
@synthesize supplementaryItems = _supplementaryItems;

+ (instancetype) itemWithLayoutSize: (NSCollectionLayoutSize *) layoutSize {
    return [self itemWithLayoutSize: layoutSize supplementaryItems: nil];
}

+ (instancetype) itemWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                  supplementaryItems: (NSArray *) supplementaryItems {
    NSCollectionLayoutItem *result = [[self alloc] init];
    result->_layoutSize = [layoutSize retain];
    result->_supplementaryItems = [supplementaryItems copy];
    return [result autorelease];
}

- (void) dealloc {
    [_layoutSize release];
    [_supplementaryItems release];
    [_edgeSpacing release];
    [super dealloc];
}

// Subclasses add their own state by overriding -copyWithZone: and calling this.
- (id) copyWithZone: (NSZone *) zone {
    NSCollectionLayoutItem *copy = [[[self class] allocWithZone: zone] init];
    copy->_layoutSize = [_layoutSize retain];
    copy->_supplementaryItems = [_supplementaryItems copy];
    copy->_contentInsets = _contentInsets;
    copy->_edgeSpacing = [_edgeSpacing copy];
    return copy;
}

@end
