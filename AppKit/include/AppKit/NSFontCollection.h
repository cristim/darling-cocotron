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

@class NSFontDescriptor, NSLocale;

typedef NSString *NSFontCollectionName;

// The constant names are documented at
// developer.apple.com/documentation/appkit/nsfontcollection/visibility; the
// values are a GUESS (rung 6): one bit each, in the documented order.
typedef NS_OPTIONS(NSUInteger, NSFontCollectionVisibility) {
    NSFontCollectionVisibilityProcess = 1 << 0,
    NSFontCollectionVisibilityUser = 1 << 1,
    NSFontCollectionVisibilityComputer = 1 << 2,
};

// The class is implemented in CoreText, which is the image that exports it on
// macOS; this header stays in AppKit, where the public API declares it.
// Documented at developer.apple.com/documentation/appkit/nsfontcollection
@interface NSFontCollection : NSObject <NSCoding, NSCopying, NSMutableCopying>

+ (NSFontCollection *) fontCollectionWithDescriptors: (NSArray<NSFontDescriptor *> *) queryDescriptors;
+ (NSFontCollection *) fontCollectionWithLocale: (NSLocale *) locale;
+ (NSFontCollection *) fontCollectionWithName: (NSFontCollectionName) name;
+ (NSFontCollection *) fontCollectionWithName: (NSFontCollectionName) name visibility: (NSFontCollectionVisibility) visibility;

@property(class, copy, readonly) NSFontCollection *fontCollectionWithAllAvailableDescriptors;
@property(class, copy, readonly) NSArray<NSString *> *allFontCollectionNames;

+ (BOOL) showFontCollection: (NSFontCollection *) collection
                   withName: (NSFontCollectionName) name
                 visibility: (NSFontCollectionVisibility) visibility
                      error: (NSError **) error;
+ (BOOL) hideFontCollectionWithName: (NSFontCollectionName) name
                         visibility: (NSFontCollectionVisibility) visibility
                              error: (NSError **) error;
+ (BOOL) renameFontCollectionWithName: (NSFontCollectionName) oldName
                           visibility: (NSFontCollectionVisibility) visibility
                               toName: (NSFontCollectionName) newName
                                error: (NSError **) outError;

@property(copy, readonly, nullable) NSArray<NSFontDescriptor *> *queryDescriptors;
@property(copy, readonly, nullable) NSArray<NSFontDescriptor *> *exclusionDescriptors;
@property(copy, readonly, nullable) NSArray<NSFontDescriptor *> *matchingDescriptors;

- (NSArray<NSFontDescriptor *> *) matchingDescriptorsWithOptions: (NSDictionary<NSString *, NSNumber *> *) options;
- (NSArray<NSFontDescriptor *> *) matchingDescriptorsForFamily: (NSString *) family;
- (NSArray<NSFontDescriptor *> *) matchingDescriptorsForFamily: (NSString *) family
                                                       options: (NSDictionary<NSString *, NSNumber *> *) options;

@end

// Documented at developer.apple.com/documentation/appkit/nsmutablefontcollection
@interface NSMutableFontCollection : NSFontCollection

+ (NSMutableFontCollection *) fontCollectionWithDescriptors: (NSArray<NSFontDescriptor *> *) queryDescriptors;
+ (NSMutableFontCollection *) fontCollectionWithLocale: (NSLocale *) locale;
+ (NSMutableFontCollection *) fontCollectionWithName: (NSFontCollectionName) name;
+ (NSMutableFontCollection *) fontCollectionWithName: (NSFontCollectionName) name visibility: (NSFontCollectionVisibility) visibility;

@property(class, copy, readonly) NSMutableFontCollection *fontCollectionWithAllAvailableDescriptors;

@property(copy, nullable) NSArray<NSFontDescriptor *> *queryDescriptors;
@property(copy, nullable) NSArray<NSFontDescriptor *> *exclusionDescriptors;

- (void) addQueryForDescriptors: (NSArray<NSFontDescriptor *> *) descriptors;
- (void) removeQueryForDescriptors: (NSArray<NSFontDescriptor *> *) descriptors;

@end
