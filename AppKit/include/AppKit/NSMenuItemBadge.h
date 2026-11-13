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

// The constant names are documented at
// developer.apple.com/documentation/appkit/nsmenuitembadgetype; the values
// are a GUESS (rung 6) because the documentation does not give them.
typedef NS_ENUM(NSInteger, NSMenuItemBadgeType) {
    NSMenuItemBadgeTypeNone = 0,
    NSMenuItemBadgeTypeUpdates = 1,
    NSMenuItemBadgeTypeNewItems = 2,
    NSMenuItemBadgeTypeAlerts = 3,
};

// Documented at developer.apple.com/documentation/appkit/nsmenuitembadge
@interface NSMenuItemBadge : NSObject <NSCopying>

- (instancetype) initWithCount: (NSInteger) itemCount;
- (instancetype) initWithString: (NSString *) string;
+ (instancetype) alertsWithCount: (NSInteger) itemCount;
+ (instancetype) newItemsWithCount: (NSInteger) itemCount;
+ (instancetype) updatesWithCount: (NSInteger) itemCount;

@property(readonly) NSInteger itemCount;
@property(readonly, nullable) NSString *stringValue;
@property(readonly) NSMenuItemBadgeType type;

@end
