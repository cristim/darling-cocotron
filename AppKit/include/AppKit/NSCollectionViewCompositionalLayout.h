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

#import <AppKit/AppKitExport.h>
#import <AppKit/NSLayoutConstraint.h>
#import <Foundation/Foundation.h>

// The classes that describe a compositional layout. They are plain value
// objects; nothing lays items out from them yet.

@class NSCollectionLayoutSection, NSCollectionLayoutBoundarySupplementaryItem,
        NSCollectionLayoutDecorationItem, NSCollectionLayoutSupplementaryItem;

@interface NSCollectionLayoutDimension : NSObject <NSCopying> {
    NSInteger _kind;
    CGFloat _dimension;
}
+ (instancetype) fractionalWidthDimension: (CGFloat) fraction;
+ (instancetype) fractionalHeightDimension: (CGFloat) fraction;
+ (instancetype) absoluteDimension: (CGFloat) absoluteDimension;
+ (instancetype) estimatedDimension: (CGFloat) estimatedDimension;
@property(readonly) CGFloat dimension;
@property(readonly, getter=isFractionalWidth) BOOL fractionalWidth;
@property(readonly, getter=isFractionalHeight) BOOL fractionalHeight;
@property(readonly, getter=isAbsolute) BOOL absolute;
@property(readonly, getter=isEstimated) BOOL estimated;
@end

@interface NSCollectionLayoutSize : NSObject <NSCopying> {
    NSCollectionLayoutDimension *_widthDimension;
    NSCollectionLayoutDimension *_heightDimension;
}
+ (instancetype) sizeWithWidthDimension: (NSCollectionLayoutDimension *) width
                        heightDimension: (NSCollectionLayoutDimension *) height;
@property(readonly, retain) NSCollectionLayoutDimension *widthDimension;
@property(readonly, retain) NSCollectionLayoutDimension *heightDimension;
@end

@interface NSCollectionLayoutSpacing : NSObject <NSCopying> {
    CGFloat _spacing;
    BOOL _flexible;
}
+ (instancetype) flexibleSpacing: (CGFloat) flexibleSpacing;
+ (instancetype) fixedSpacing: (CGFloat) fixedSpacing;
@property(readonly) CGFloat spacing;
@property(readonly, getter=isFlexibleSpacing) BOOL flexibleSpacing;
@property(readonly, getter=isFixedSpacing) BOOL fixedSpacing;
@end

@interface NSCollectionLayoutEdgeSpacing : NSObject <NSCopying> {
    NSCollectionLayoutSpacing *_leading, *_top, *_trailing, *_bottom;
}
+ (instancetype) spacingForLeading: (NSCollectionLayoutSpacing *) leading
                               top: (NSCollectionLayoutSpacing *) top
                          trailing: (NSCollectionLayoutSpacing *) trailing
                            bottom: (NSCollectionLayoutSpacing *) bottom;
@property(readonly, retain) NSCollectionLayoutSpacing *leading;
@property(readonly, retain) NSCollectionLayoutSpacing *top;
@property(readonly, retain) NSCollectionLayoutSpacing *trailing;
@property(readonly, retain) NSCollectionLayoutSpacing *bottom;
@end

@interface NSCollectionLayoutAnchor : NSObject <NSCopying> {
    NSDirectionalRectEdge _edges;
    NSPoint _offset;
    BOOL _fractionalOffset;
}
+ (instancetype) layoutAnchorWithEdges: (NSDirectionalRectEdge) edges;
+ (instancetype) layoutAnchorWithEdges: (NSDirectionalRectEdge) edges
                        absoluteOffset: (NSPoint) absoluteOffset;
+ (instancetype) layoutAnchorWithEdges: (NSDirectionalRectEdge) edges
                        fractionalOffset: (NSPoint) fractionalOffset;
@property(readonly) NSDirectionalRectEdge edges;
@property(readonly) NSPoint offset;
@property(readonly, getter=isAbsoluteOffset) BOOL absoluteOffset;
@property(readonly, getter=isFractionalOffset) BOOL fractionalOffset;
@end

@interface NSCollectionLayoutItem : NSObject <NSCopying> {
    NSCollectionLayoutSize *_layoutSize;
    NSArray *_supplementaryItems;
    NSDirectionalEdgeInsets _contentInsets;
    NSCollectionLayoutEdgeSpacing *_edgeSpacing;
}
+ (instancetype) itemWithLayoutSize: (NSCollectionLayoutSize *) layoutSize;
+ (instancetype) itemWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                  supplementaryItems: (NSArray<NSCollectionLayoutSupplementaryItem *> *) supplementaryItems;
@property NSDirectionalEdgeInsets contentInsets;
@property(copy) NSCollectionLayoutEdgeSpacing *edgeSpacing;
@property(readonly, retain) NSCollectionLayoutSize *layoutSize;
@property(readonly, copy) NSArray<NSCollectionLayoutSupplementaryItem *> *supplementaryItems;
@end
