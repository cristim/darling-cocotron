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

#import <AppKit/NSScrubberLayoutAttributes.h>

// The documentation does not give the defaults: the frame starts empty and
// the alpha starts at 1.0, a GUESS (rung 6).
@implementation NSScrubberLayoutAttributes

@synthesize itemIndex = _itemIndex;
@synthesize frame = _frame;
@synthesize alpha = _alpha;

- (instancetype) init {
    if ((self = [super init]) != nil)
        _alpha = 1.0;
    return self;
}

+ (instancetype) layoutAttributesForItemAtIndex: (NSInteger) index {
    NSScrubberLayoutAttributes *attributes = [[[self alloc] init] autorelease];
    attributes.itemIndex = index;
    return attributes;
}

- (id) copyWithZone: (NSZone *) zone {
    NSScrubberLayoutAttributes *copy = [[[self class] allocWithZone: zone] init];
    copy.itemIndex = _itemIndex;
    copy.frame = _frame;
    copy.alpha = _alpha;
    return copy;
}

@end
