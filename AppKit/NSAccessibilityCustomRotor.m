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


#import <AppKit/NSAccessibilityCustomRotor.h>

@implementation NSAccessibilityCustomRotorSearchParameters

- (void) dealloc {
    [_currentItem release];
    [_filterString release];
    [super dealloc];
}

@end

@implementation NSAccessibilityCustomRotorItemResult

- (instancetype) initWithTargetElement: (id<NSAccessibilityElement>) targetElement {
    if ((self = [super init])) {
        _targetElement = targetElement;
        _targetRange = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

- (instancetype) initWithItemLoadingToken: (NSAccessibilityLoadingToken) itemLoadingToken
                              customLabel: (NSString *) customLabel {
    if ((self = [super init])) {
        _itemLoadingToken = [itemLoadingToken retain];
        _customLabel = [customLabel copy];
        _targetRange = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

- (void) dealloc {
    [_itemLoadingToken release];
    [_customLabel release];
    [super dealloc];
}

@end

@implementation NSAccessibilityCustomRotor

- (instancetype) initWithRotorType: (NSAccessibilityCustomRotorType) rotorType
                itemSearchDelegate: (id<NSAccessibilityCustomRotorItemSearchDelegate>) itemSearchDelegate {
    if ((self = [super init])) {
        _type = rotorType;
        _itemSearchDelegate = itemSearchDelegate;
    }
    return self;
}

- (instancetype) initWithLabel: (NSString *) label
            itemSearchDelegate: (id<NSAccessibilityCustomRotorItemSearchDelegate>) itemSearchDelegate {
    if ((self = [super init])) {
        _label = [label copy];
        _itemSearchDelegate = itemSearchDelegate;
    }
    return self;
}

- (void) dealloc {
    [_label release];
    [super dealloc];
}

@end
