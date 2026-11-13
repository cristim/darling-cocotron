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

#import <Foundation/NSObject.h>

@class NSArray;

// The case names are from the public documentation (rung 3,
// developer.apple.com coredata/nspersistentstorerequesttype). Every raw value is a GUESS (rung 6; NEEDS-REAL-MAC): the
// documented order, numbered from 1.
typedef NS_ENUM(NSUInteger, NSPersistentStoreRequestType) {
    NSFetchRequestType = 1,
    NSSaveRequestType = 2,
    NSBatchInsertRequestType = 3,
    NSBatchUpdateRequestType = 4,
    NSBatchDeleteRequestType = 5,
};

@interface NSPersistentStoreRequest : NSObject <NSCopying> {
    NSArray *_affectedStores;
}

@property(nonatomic, retain) NSArray *affectedStores;
@property(readonly) NSPersistentStoreRequestType requestType;

@end
