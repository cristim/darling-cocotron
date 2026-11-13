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
#import <Foundation/Foundation.h>

@class NSAccessibilityCustomRotor;

// The constant names are documented at
// developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor/rotortype;
// the values are a GUESS (rung 6), listed in the documentation's order with
// Custom first.
typedef NS_ENUM(NSInteger, NSAccessibilityCustomRotorType) {
    NSAccessibilityCustomRotorTypeCustom = 0,
    NSAccessibilityCustomRotorTypeAny,
    NSAccessibilityCustomRotorTypeAnnotation,
    NSAccessibilityCustomRotorTypeBoldText,
    NSAccessibilityCustomRotorTypeHeading,
    NSAccessibilityCustomRotorTypeHeadingLevel1,
    NSAccessibilityCustomRotorTypeHeadingLevel2,
    NSAccessibilityCustomRotorTypeHeadingLevel3,
    NSAccessibilityCustomRotorTypeHeadingLevel4,
    NSAccessibilityCustomRotorTypeHeadingLevel5,
    NSAccessibilityCustomRotorTypeHeadingLevel6,
    NSAccessibilityCustomRotorTypeImage,
    NSAccessibilityCustomRotorTypeItalicText,
    NSAccessibilityCustomRotorTypeLandmark,
    NSAccessibilityCustomRotorTypeLink,
    NSAccessibilityCustomRotorTypeList,
    NSAccessibilityCustomRotorTypeMisspelledWord,
    NSAccessibilityCustomRotorTypeTable,
    NSAccessibilityCustomRotorTypeTextField,
    NSAccessibilityCustomRotorTypeUnderlinedText,
    NSAccessibilityCustomRotorTypeVisitedLink,
    NSAccessibilityCustomRotorTypeAudiograph,
};

// The documentation names both protocols and their purpose but the members
// were not recorded, so neither declares any (GUESS, rung 6).
@protocol NSAccessibilityCustomRotorItemSearchDelegate <NSObject>
@end

@protocol NSAccessibilityElementLoading <NSObject>
@end

// Documented at developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor
@interface NSAccessibilityCustomRotor : NSObject

- (instancetype) initWithRotorType: (NSAccessibilityCustomRotorType) rotorType
                itemSearchDelegate: (id<NSAccessibilityCustomRotorItemSearchDelegate>) itemSearchDelegate;
- (instancetype) initWithLabel: (NSString *) label
            itemSearchDelegate: (id<NSAccessibilityCustomRotorItemSearchDelegate>) itemSearchDelegate;

@property NSAccessibilityCustomRotorType type;
@property(copy) NSString *label;
@property(weak) id<NSAccessibilityCustomRotorItemSearchDelegate> itemSearchDelegate;
@property(weak, nullable) id<NSAccessibilityElementLoading> itemLoadingDelegate;

@end
