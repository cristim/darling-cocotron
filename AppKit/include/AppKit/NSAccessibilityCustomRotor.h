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
#import <AppKit/NSAccessibilityProtocols.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSAccessibilityCustomRotor;
@class NSAccessibilityCustomRotorItemResult;
@class NSAccessibilityCustomRotorSearchParameters;

typedef id<NSSecureCoding, NSObject> NSAccessibilityLoadingToken;

// Member constants of these two are not declared: their numeric values are
// not established from public documentation.
typedef NSInteger NSAccessibilityCustomRotorType
    NS_SWIFT_NAME(NSAccessibilityCustomRotor.RotorType);
typedef NSInteger NSAccessibilityCustomRotorSearchDirection
    NS_SWIFT_NAME(NSAccessibilityCustomRotor.SearchDirection);

@protocol NSAccessibilityElementLoading <NSObject>

- (nullable id<NSAccessibilityElement>) accessibilityElementWithToken: (NSAccessibilityLoadingToken) token;

@optional
- (NSRange) accessibilityRangeInTargetElementWithToken: (NSAccessibilityLoadingToken) token;

@end

@protocol NSAccessibilityCustomRotorItemSearchDelegate <NSObject>

@required
- (nullable NSAccessibilityCustomRotorItemResult *) rotor: (NSAccessibilityCustomRotor *) rotor
                                 resultForSearchParameters: (NSAccessibilityCustomRotorSearchParameters *) searchParameters;

@end

APPKIT_EXPORT
NS_SWIFT_NAME(NSAccessibilityCustomRotor.SearchParameters)
@interface NSAccessibilityCustomRotorSearchParameters : NSObject

@property(nullable, retain) NSAccessibilityCustomRotorItemResult *currentItem;
@property NSAccessibilityCustomRotorSearchDirection searchDirection;
@property(copy) NSString *filterString;

@end

APPKIT_EXPORT
NS_SWIFT_NAME(NSAccessibilityCustomRotor.ItemResult)
@interface NSAccessibilityCustomRotorItemResult : NSObject

- (instancetype) initWithTargetElement: (id<NSAccessibilityElement>) targetElement;
- (instancetype) initWithItemLoadingToken: (NSAccessibilityLoadingToken) itemLoadingToken
                              customLabel: (NSString *) customLabel;

@property(nullable, assign) id<NSAccessibilityElement> targetElement;
@property(nullable, retain) NSAccessibilityLoadingToken itemLoadingToken;
@property NSRange targetRange;
@property(nullable, copy) NSString *customLabel;

@end

APPKIT_EXPORT
@interface NSAccessibilityCustomRotor : NSObject

- (instancetype) initWithRotorType: (NSAccessibilityCustomRotorType) rotorType
                itemSearchDelegate: (id<NSAccessibilityCustomRotorItemSearchDelegate>) itemSearchDelegate;
- (instancetype) initWithLabel: (NSString *) label
            itemSearchDelegate: (id<NSAccessibilityCustomRotorItemSearchDelegate>) itemSearchDelegate;

@property NSAccessibilityCustomRotorType type;
@property(copy) NSString *label;
@property(nullable, assign) id<NSAccessibilityCustomRotorItemSearchDelegate> itemSearchDelegate;
@property(nullable, assign) id<NSAccessibilityElementLoading> itemLoadingDelegate;

@end

NS_ASSUME_NONNULL_END
