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

#import <AppKit/NSAppearance.h>
#import <AppKit/NSColor.h>

NSString *const NSAppearanceNameAqua = @"NSAppearanceNameAqua";
NSString *const NSAppearanceNameDarkAqua = @"NSAppearanceNameDarkAqua";
NSString *const NSAppearanceNameSystem = @"NSAppearanceNameSystem";
NSString *const NSAppearanceNameTouchBar = @"NSAppearanceNameTouchBar";
NSString *const NSAppearanceNameLightContent = @"NSAppearanceNameLightContent";
NSString *const NSAppearanceNameVibrantDark = @"NSAppearanceNameVibrantDark";
NSString *const NSAppearanceNameVibrantLight = @"NSAppearanceNameVibrantLight";
NSString *const NSAppearanceNameAccessibilityHighContrastAqua =
        @"NSAppearanceNameAccessibilityHighContrastAqua";
NSString *const NSAppearanceNameAccessibilityHighContrastDarkAqua =
        @"NSAppearanceNameAccessibilityHighContrastDarkAqua";
NSString *const NSAppearanceNameAccessibilityHighContrastSystem =
        @"NSAppearanceNameAccessibilityHighContrastSystem";
NSString *const NSAppearanceNameAccessibilityHighContrastVibrantLight =
        @"NSAppearanceNameAccessibilityHighContrastVibrantLight";
NSString *const NSAppearanceNameAccessibilityHighContrastVibrantDark =
        @"NSAppearanceNameAccessibilityHighContrastVibrantDark";

NSString *const NSAppearanceNameControlStrip =
        @"NSAppearanceNameControlStrip"; // Undocumented

static NSAppearance *sCurrentAppearance = nil;

BOOL NSSolariumEnabled(void) {
    return NO;
}

@implementation NSAppearance

+ (NSAppearance *) appearanceNamed: (NSAppearanceName) name {
    NSAppearance *appearance = [[NSAppearance alloc] init];
    appearance->_name = [name copy];
    return appearance;
}

+ (NSAppearance *) currentAppearance {
    if (!sCurrentAppearance) {
        sCurrentAppearance = [self appearanceNamed:NSAppearanceNameAqua];
    }
    return sCurrentAppearance;
}

+ (void) setCurrentAppearance: (NSAppearance *) appearance {
    if (sCurrentAppearance != appearance) {
        [sCurrentAppearance release];
        sCurrentAppearance = [appearance retain];
    }
}

- (NSAppearanceName) name {
    return _name ? _name : NSAppearanceNameAqua;
}

// How far colorByAdjustingLightnessOfColor:darker: blends towards black or white.
static const CGFloat NSAppearanceLightnessAdjustment = 0.1;

+ (NSColor *) colorByAdjustingLightnessOfColor: (NSColor *) color darker: (BOOL) darker {
    NSColor *target = darker ? [NSColor blackColor] : [NSColor whiteColor];
    NSColor *result = [color blendedColorWithFraction: NSAppearanceLightnessAdjustment
                                              ofColor: target];
    return result ? result : color;
}

- (NSAppearanceName) bestMatchFromAppearancesWithNames: (NSArray *) appearances {
    if ([appearances containsObject: [self name]]) {
        return [self name];
    }
    if ([appearances count] > 0) {
        return [appearances objectAtIndex: 0];
    }
    return nil;
}

- (void) encodeWithCoder: (NSCoder *) aCoder {
    printf("STUB %s\n", __PRETTY_FUNCTION__);
}

- (id) initWithCoder: (NSCoder *) aDecoder {
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return self;
}

+ (BOOL) supportsSecureCoding
{
    return YES;
}

@end
