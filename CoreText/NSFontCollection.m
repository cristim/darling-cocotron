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

#import <AppKit/NSFontCollection.h>

// NSFontCollection lives in CoreText because that is the image macOS exports
// it from. There is no font matching behind it: a collection stores its query
// and exclusion descriptors, matchingDescriptors is empty, and named
// collections cannot be shown, hidden or renamed. All of that is a GUESS (rung
// 6) except the documented factories and accessors.
@implementation NSFontCollection {
  @protected
    NSArray *_queryDescriptors;
    NSArray *_exclusionDescriptors;
}

+ (NSFontCollection *) fontCollectionWithDescriptors: (NSArray *) queryDescriptors {
    NSFontCollection *collection = [[[self alloc] init] autorelease];
    collection->_queryDescriptors = [queryDescriptors copy];
    return collection;
}

+ (NSFontCollection *) fontCollectionWithLocale: (NSLocale *) locale {
    return [[[self alloc] init] autorelease];
}

+ (NSFontCollection *) fontCollectionWithName: (NSFontCollectionName) name {
    return [[[self alloc] init] autorelease];
}

+ (NSFontCollection *) fontCollectionWithName: (NSFontCollectionName) name visibility: (NSFontCollectionVisibility) visibility {
    return [[[self alloc] init] autorelease];
}

+ (NSFontCollection *) fontCollectionWithAllAvailableDescriptors {
    return [[[self alloc] init] autorelease];
}

+ (NSArray *) allFontCollectionNames {
    return @[];
}

+ (BOOL) showFontCollection: (NSFontCollection *) collection
                   withName: (NSFontCollectionName) name
                 visibility: (NSFontCollectionVisibility) visibility
                      error: (NSError **) error {
    return NO;
}

+ (BOOL) hideFontCollectionWithName: (NSFontCollectionName) name
                         visibility: (NSFontCollectionVisibility) visibility
                              error: (NSError **) error {
    return NO;
}

+ (BOOL) renameFontCollectionWithName: (NSFontCollectionName) oldName
                           visibility: (NSFontCollectionVisibility) visibility
                               toName: (NSFontCollectionName) newName
                                error: (NSError **) outError {
    return NO;
}

- (NSArray *) queryDescriptors {
    return _queryDescriptors;
}

- (NSArray *) exclusionDescriptors {
    return _exclusionDescriptors;
}

- (NSArray *) matchingDescriptors {
    return @[];
}

- (NSArray *) matchingDescriptorsWithOptions: (NSDictionary *) options {
    return @[];
}

- (NSArray *) matchingDescriptorsForFamily: (NSString *) family {
    return @[];
}

- (NSArray *) matchingDescriptorsForFamily: (NSString *) family options: (NSDictionary *) options {
    return @[];
}

- (id) copyWithZone: (NSZone *) zone {
    NSFontCollection *copy = [[NSFontCollection allocWithZone: zone] init];
    copy->_queryDescriptors = [_queryDescriptors copy];
    copy->_exclusionDescriptors = [_exclusionDescriptors copy];
    return copy;
}

- (id) mutableCopyWithZone: (NSZone *) zone {
    NSFontCollection *copy = [[NSMutableFontCollection allocWithZone: zone] init];
    copy->_queryDescriptors = [_queryDescriptors copy];
    copy->_exclusionDescriptors = [_exclusionDescriptors copy];
    return copy;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    [coder encodeObject: _queryDescriptors forKey: @"NSQueryDescriptors"];
    [coder encodeObject: _exclusionDescriptors forKey: @"NSExclusionDescriptors"];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    if ((self = [super init]) != nil) {
        _queryDescriptors = [[coder decodeObjectForKey: @"NSQueryDescriptors"] retain];
        _exclusionDescriptors = [[coder decodeObjectForKey: @"NSExclusionDescriptors"] retain];
    }
    return self;
}

- (void) dealloc {
    [_queryDescriptors release];
    [_exclusionDescriptors release];
    [super dealloc];
}

@end

@implementation NSMutableFontCollection

@dynamic queryDescriptors, exclusionDescriptors;

+ (NSMutableFontCollection *) fontCollectionWithDescriptors: (NSArray *) queryDescriptors {
    return (NSMutableFontCollection *) [super fontCollectionWithDescriptors: queryDescriptors];
}

+ (NSMutableFontCollection *) fontCollectionWithLocale: (NSLocale *) locale {
    return (NSMutableFontCollection *) [super fontCollectionWithLocale: locale];
}

+ (NSMutableFontCollection *) fontCollectionWithName: (NSFontCollectionName) name {
    return (NSMutableFontCollection *) [super fontCollectionWithName: name];
}

+ (NSMutableFontCollection *) fontCollectionWithName: (NSFontCollectionName) name visibility: (NSFontCollectionVisibility) visibility {
    return (NSMutableFontCollection *) [super fontCollectionWithName: name visibility: visibility];
}

+ (NSMutableFontCollection *) fontCollectionWithAllAvailableDescriptors {
    return (NSMutableFontCollection *) [super fontCollectionWithAllAvailableDescriptors];
}

- (void) setQueryDescriptors: (NSArray *) descriptors {
    [_queryDescriptors autorelease];
    _queryDescriptors = [descriptors copy];
}

- (void) setExclusionDescriptors: (NSArray *) descriptors {
    [_exclusionDescriptors autorelease];
    _exclusionDescriptors = [descriptors copy];
}

- (void) addQueryForDescriptors: (NSArray *) descriptors {
    NSMutableArray *query = [NSMutableArray arrayWithArray: _queryDescriptors ?: @[]];
    [query addObjectsFromArray: descriptors];
    [self setQueryDescriptors: query];
}

- (void) removeQueryForDescriptors: (NSArray *) descriptors {
    NSMutableArray *query = [NSMutableArray arrayWithArray: _queryDescriptors ?: @[]];
    [query removeObjectsInArray: descriptors];
    [self setQueryDescriptors: query];
}

@end
