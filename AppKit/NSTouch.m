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

#import <AppKit/NSTouch.h>

// Touches are created by the event system, so every property is read-only and
// starts zeroed. How a normalized position maps into a view is not documented;
// both location methods return the origin, a GUESS (rung 6).
@implementation NSTouch {
    NSTouchType _type;
    id<NSCopying, NSObject> _identity;
    NSTouchPhase _phase;
    NSPoint _normalizedPosition;
    BOOL _resting;
    id _device;
    NSSize _deviceSize;
}

@synthesize type = _type;
@synthesize identity = _identity;
@synthesize phase = _phase;
@synthesize normalizedPosition = _normalizedPosition;
@synthesize resting = _resting;
@synthesize device = _device;
@synthesize deviceSize = _deviceSize;

- (NSPoint) locationInView: (NSView *) view {
    return NSZeroPoint;
}

- (NSPoint) previousLocationInView: (NSView *) view {
    return NSZeroPoint;
}

- (void) dealloc {
    [(id) _identity release];
    [_device release];
    [super dealloc];
}

- (id) copyWithZone: (NSZone *) zone {
    NSTouch *copy = [[[self class] allocWithZone: zone] init];
    copy->_type = _type;
    copy->_identity = [(id) _identity retain];
    copy->_phase = _phase;
    copy->_normalizedPosition = _normalizedPosition;
    copy->_resting = _resting;
    copy->_device = [_device retain];
    copy->_deviceSize = _deviceSize;
    return copy;
}

@end
