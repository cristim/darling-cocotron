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

// Apple defines these classes in CollectionViewCore and AppKit re-exports them. A process must see
// exactly one definition: a client that links Apple's CollectionViewCore would otherwise meet a second
// class of the same name inside AppKit.

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

