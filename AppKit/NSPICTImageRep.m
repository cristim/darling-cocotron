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

#import <AppKit/NSPICTImageRep.h>
#import "NSStubForwarding-Private.h"

// No PICT decoder exists, so every message beyond the data accessor is logged
// once and ignored, and the bounding box is empty. The documentation says
// initWithData: fails for data that is not PICT; without a decoder that check
// is a GUESS (rung 6): any non-empty data is accepted.
@implementation NSPICTImageRep {
    NSData *_PICTRepresentation;
}

NS_STUB_FORWARDING

@synthesize PICTRepresentation = _PICTRepresentation;

+ (instancetype) imageRepWithData: (NSData *) pictData {
    return [[[self alloc] initWithData: pictData] autorelease];
}

- (instancetype) initWithData: (NSData *) pictData {
    if ([pictData length] == 0) {
        [self release];
        return nil;
    }
    if ((self = [super init]) != nil)
        _PICTRepresentation = [pictData copy];
    return self;
}

- (NSRect) boundingBox {
    return NSZeroRect;
}

- (void) dealloc {
    [_PICTRepresentation release];
    [super dealloc];
}

@end
