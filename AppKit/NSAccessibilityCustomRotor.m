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

#import <AppKit/NSAccessibilityCustomRotor.h>

// The rotor stores its documented properties; nothing consults the search
// delegate, because no assistive technology drives it. A label-based rotor
// has the custom type and a type-based rotor has an empty label, a GUESS
// (rung 6).
@implementation NSAccessibilityCustomRotor {
    NSAccessibilityCustomRotorType _type;
    NSString *_label;
    id<NSAccessibilityCustomRotorItemSearchDelegate> _itemSearchDelegate;
    id<NSAccessibilityElementLoading> _itemLoadingDelegate;
}

@synthesize type = _type;
@synthesize label = _label;
@synthesize itemSearchDelegate = _itemSearchDelegate;
@synthesize itemLoadingDelegate = _itemLoadingDelegate;

- (instancetype) initWithRotorType: (NSAccessibilityCustomRotorType) rotorType
                itemSearchDelegate: (id<NSAccessibilityCustomRotorItemSearchDelegate>) itemSearchDelegate {
    if ((self = [super init]) != nil) {
        _type = rotorType;
        _label = @"";
        _itemSearchDelegate = itemSearchDelegate;
    }
    return self;
}

- (instancetype) initWithLabel: (NSString *) label
            itemSearchDelegate: (id<NSAccessibilityCustomRotorItemSearchDelegate>) itemSearchDelegate {
    if ((self = [self initWithRotorType: NSAccessibilityCustomRotorTypeCustom itemSearchDelegate: itemSearchDelegate]) != nil)
        self.label = label;
    return self;
}

- (void) dealloc {
    [_label release];
    [super dealloc];
}

@end
