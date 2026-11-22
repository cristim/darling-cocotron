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
#import <AppKit/NSCollectionViewFlowLayout.h>
#import <AppKit/NSLayoutConstraint.h>
#import <Foundation/Foundation.h>

// The classes that describe a compositional layout are plain value objects.
// NSCollectionViewCompositionalLayout only stores its description: nothing
// lays items out from it yet, and NSCollectionViewLayout logs each
// unimplemented call.

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

@interface NSCollectionLayoutSupplementaryItem : NSCollectionLayoutItem {
    NSString *_elementKind;
    NSCollectionLayoutAnchor *_containerAnchor;
    NSCollectionLayoutAnchor *_itemAnchor;
    NSInteger _zIndex;
}
+ (instancetype) supplementaryItemWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                                      elementKind: (NSString *) elementKind
                                  containerAnchor: (NSCollectionLayoutAnchor *) containerAnchor;
+ (instancetype) supplementaryItemWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                                      elementKind: (NSString *) elementKind
                                  containerAnchor: (NSCollectionLayoutAnchor *) containerAnchor
                                       itemAnchor: (NSCollectionLayoutAnchor *) itemAnchor;
@property NSInteger zIndex;
@property(readonly, copy) NSString *elementKind;
@property(readonly, retain) NSCollectionLayoutAnchor *containerAnchor;
@property(readonly, retain) NSCollectionLayoutAnchor *itemAnchor;
@end

@interface NSCollectionLayoutBoundarySupplementaryItem : NSCollectionLayoutSupplementaryItem {
    NSRectAlignment _alignment;
    NSPoint _offset;
    BOOL _extendsBoundary;
    BOOL _pinToVisibleBounds;
}
+ (instancetype) boundarySupplementaryItemWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                                              elementKind: (NSString *) elementKind
                                                alignment: (NSRectAlignment) alignment;
+ (instancetype) boundarySupplementaryItemWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                                              elementKind: (NSString *) elementKind
                                                alignment: (NSRectAlignment) alignment
                                           absoluteOffset: (NSPoint) absoluteOffset;
@property BOOL extendsBoundary;
@property BOOL pinToVisibleBounds;
@property(readonly) NSRectAlignment alignment;
@property(readonly) NSPoint offset;
@end

@interface NSCollectionLayoutDecorationItem : NSCollectionLayoutItem {
    NSString *_elementKind;
    NSInteger _zIndex;
}
+ (instancetype) backgroundDecorationItemWithElementKind: (NSString *) elementKind;
@property NSInteger zIndex;
@property(readonly, copy) NSString *elementKind;
@end

@interface NSCollectionLayoutGroup : NSCollectionLayoutItem {
    NSArray *_subitems;
    BOOL _vertical;
    NSCollectionLayoutSpacing *_interItemSpacing;
}
+ (instancetype) horizontalGroupWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                                        subitem: (NSCollectionLayoutItem *) subitem
                                          count: (NSInteger) count;
+ (instancetype) horizontalGroupWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                                       subitems: (NSArray<NSCollectionLayoutItem *> *) subitems;
+ (instancetype) verticalGroupWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                                      subitem: (NSCollectionLayoutItem *) subitem
                                        count: (NSInteger) count;
+ (instancetype) verticalGroupWithLayoutSize: (NSCollectionLayoutSize *) layoutSize
                                     subitems: (NSArray<NSCollectionLayoutItem *> *) subitems;
@property(copy) NSCollectionLayoutSpacing *interItemSpacing;
@property(readonly, copy) NSArray<NSCollectionLayoutItem *> *subitems;
@end

@interface NSCollectionLayoutSection : NSObject <NSCopying> {
    NSCollectionLayoutGroup *_group;
    NSDirectionalEdgeInsets _contentInsets;
    CGFloat _interGroupSpacing;
    NSArray *_boundarySupplementaryItems;
    NSArray *_decorationItems;
    BOOL _supplementariesFollowContentInsets;
}
+ (instancetype) sectionWithGroup: (NSCollectionLayoutGroup *) group;
@property NSDirectionalEdgeInsets contentInsets;
@property CGFloat interGroupSpacing;
@property(copy) NSArray<NSCollectionLayoutBoundarySupplementaryItem *> *boundarySupplementaryItems;
@property BOOL supplementariesFollowContentInsets;
@property(copy) NSArray<NSCollectionLayoutDecorationItem *> *decorationItems;
@end

@protocol NSCollectionLayoutContainer <NSObject>
@property(readonly) NSSize contentSize;
@property(readonly) NSSize effectiveContentSize;
@property(readonly) NSDirectionalEdgeInsets contentInsets;
@property(readonly) NSDirectionalEdgeInsets effectiveContentInsets;
@end

@protocol NSCollectionLayoutEnvironment <NSObject>
@property(readonly) id<NSCollectionLayoutContainer> container;
@end

typedef NSCollectionLayoutSection * (^NSCollectionViewCompositionalLayoutSectionProvider)(
        NSInteger sectionIndex, id<NSCollectionLayoutEnvironment> layoutEnvironment);

@interface NSCollectionViewCompositionalLayoutConfiguration : NSObject <NSCopying> {
    NSCollectionViewScrollDirection _scrollDirection;
    CGFloat _interSectionSpacing;
    NSArray *_boundarySupplementaryItems;
}
@property NSCollectionViewScrollDirection scrollDirection;
@property CGFloat interSectionSpacing;
@property(copy) NSArray<NSCollectionLayoutBoundarySupplementaryItem *> *boundarySupplementaryItems;
@end

@interface NSCollectionViewCompositionalLayout : NSCollectionViewLayout {
    NSCollectionLayoutSection *_section;
    NSCollectionViewCompositionalLayoutSectionProvider _sectionProvider;
    NSCollectionViewCompositionalLayoutConfiguration *_configuration;
}
- (instancetype) initWithSection: (NSCollectionLayoutSection *) section;
- (instancetype) initWithSection: (NSCollectionLayoutSection *) section
                    configuration: (NSCollectionViewCompositionalLayoutConfiguration *) configuration;
- (instancetype) initWithSectionProvider: (NSCollectionViewCompositionalLayoutSectionProvider) sectionProvider;
- (instancetype) initWithSectionProvider: (NSCollectionViewCompositionalLayoutSectionProvider) sectionProvider
                            configuration: (NSCollectionViewCompositionalLayoutConfiguration *) configuration;
@property(copy) NSCollectionViewCompositionalLayoutConfiguration *configuration;
@end
