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

#import <AppKit/NSMenuItemBadge.h>

// The predefined labels of the alerts, new items and updates badges are not
// documented; their stringValue is the empty string, a GUESS (rung 6).
@implementation NSMenuItemBadge {
    NSInteger _itemCount;
    NSString *_stringValue;
    NSMenuItemBadgeType _type;
}

@synthesize itemCount = _itemCount;
@synthesize stringValue = _stringValue;
@synthesize type = _type;

- (instancetype) initWithCount: (NSInteger) itemCount type: (NSMenuItemBadgeType) type string: (NSString *) string {
    if ((self = [super init]) != nil) {
        _itemCount = itemCount;
        _type = type;
        _stringValue = [string copy];
    }
    return self;
}

- (instancetype) initWithCount: (NSInteger) itemCount {
    return [self initWithCount: itemCount type: NSMenuItemBadgeTypeNone string: @""];
}

- (instancetype) initWithCount: (NSInteger) itemCount type: (NSMenuItemBadgeType) type {
    return [self initWithCount: itemCount type: type string: @""];
}

- (instancetype) initWithString: (NSString *) string {
    return [self initWithCount: 0 type: NSMenuItemBadgeTypeNone string: string];
}

+ (instancetype) alertsWithCount: (NSInteger) itemCount {
    return [[[self alloc] initWithCount: itemCount type: NSMenuItemBadgeTypeAlerts string: @""] autorelease];
}

+ (instancetype) newItemsWithCount: (NSInteger) itemCount {
    return [[[self alloc] initWithCount: itemCount type: NSMenuItemBadgeTypeNewItems string: @""] autorelease];
}

+ (instancetype) updatesWithCount: (NSInteger) itemCount {
    return [[[self alloc] initWithCount: itemCount type: NSMenuItemBadgeTypeUpdates string: @""] autorelease];
}

- (void) dealloc {
    [_stringValue release];
    [super dealloc];
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

@end
