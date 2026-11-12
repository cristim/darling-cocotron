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

#import <AppKit/NSAccessibilityCustomAction.h>

// Holds the action; nothing performs it, because no accessibility client
// exists on this backend to ask for it.
@implementation NSAccessibilityCustomAction
@synthesize name = _name;
@synthesize handler = _handler;
@synthesize target = _target;
@synthesize selector = _selector;

- (instancetype) initWithName: (NSString *) name handler: (BOOL (^)(void)) handler {
    if ((self = [super init]) != nil) {
        _name = [name copy];
        _handler = [handler copy];
    }
    return self;
}

- (instancetype) initWithName: (NSString *) name
                       target: (id<NSObject>) target
                     selector: (SEL) selector {
    if ((self = [super init]) != nil) {
        _name = [name copy];
        _target = target;
        _selector = selector;
    }
    return self;
}

- (void) dealloc {
    [_name release];
    [_handler release];
    [super dealloc];
}

@end
