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

#import <CoreData/NSPersistentStoreRequest.h>

@class NSDictionary, NSEntityDescription, NSPredicate, NSString;

// Raw values are a GUESS (rung 6; NEEDS-REAL-MAC): the documented order from 0.
typedef NS_ENUM(NSUInteger, NSBatchUpdateRequestResultType) {
    NSStatusOnlyResultType = 0,
    NSUpdatedObjectIDsResultType = 1,
    NSUpdatedObjectsCountResultType = 2,
};

// A description of an update. No store executes it yet: this CoreData has no
// executeRequest:error:, so a request built here can only be inspected.
@interface NSBatchUpdateRequest : NSPersistentStoreRequest {
    NSString *_entityName;
    NSEntityDescription *_entity;
    NSPredicate *_predicate;
    NSDictionary *_propertiesToUpdate;
    NSBatchUpdateRequestResultType _resultType;
    BOOL _includesSubentities;
}

+ (instancetype) batchUpdateRequestWithEntityName: (NSString *) entityName;
- (instancetype) initWithEntityName: (NSString *) entityName;
- (instancetype) initWithEntity: (NSEntityDescription *) entity;

@property(readonly, copy) NSString *entityName;
@property(readonly, retain) NSEntityDescription *entity;
@property(retain) NSPredicate *predicate;
@property(copy) NSDictionary *propertiesToUpdate;
@property NSBatchUpdateRequestResultType resultType;
@property BOOL includesSubentities;

@end
