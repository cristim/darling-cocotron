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

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>

@class NSView;

// The constant names are documented at
// developer.apple.com/documentation/appkit/nstouch/touchtype,
// .../touchtypemask and .../phase-swift.struct; the documentation gives no
// values, so these are a GUESS (rung 6): one bit per constant, with
// Touching the union of the three live phases.
typedef NS_ENUM(NSInteger, NSTouchType) {
    NSTouchTypeDirect = 0,
    NSTouchTypeIndirect = 1,
};

typedef NS_OPTIONS(NSUInteger, NSTouchTypeMask) {
    NSTouchTypeMaskDirect = 1 << NSTouchTypeDirect,
    NSTouchTypeMaskIndirect = 1 << NSTouchTypeIndirect,
};

static inline NSTouchTypeMask NSTouchTypeMaskFromType(NSTouchType type) {
    return (NSTouchTypeMask) (1 << type);
}

typedef NS_OPTIONS(NSUInteger, NSTouchPhase) {
    NSTouchPhaseBegan = 1 << 0,
    NSTouchPhaseMoved = 1 << 1,
    NSTouchPhaseStationary = 1 << 2,
    NSTouchPhaseEnded = 1 << 3,
    NSTouchPhaseCancelled = 1 << 4,
    NSTouchPhaseTouching = NSTouchPhaseBegan | NSTouchPhaseMoved | NSTouchPhaseStationary,
    NSTouchPhaseAny = NSUIntegerMax,
};

// Documented at developer.apple.com/documentation/appkit/nstouch
@interface NSTouch : NSObject <NSCopying>

@property(readonly) NSTouchType type;
@property(strong, readonly) id<NSCopying, NSObject> identity;
@property(readonly) NSTouchPhase phase;
@property(readonly) NSPoint normalizedPosition;
@property(readonly, getter=isResting) BOOL resting;
@property(strong, readonly, nullable) id device;
@property(readonly) NSSize deviceSize;

- (NSPoint) locationInView: (nullable NSView *) view;
- (NSPoint) previousLocationInView: (nullable NSView *) view;

@end
