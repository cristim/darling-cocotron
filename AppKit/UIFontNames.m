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

#import <AppKit/NSFontDescriptor.h>

// Names UIKit declares for the same font machinery. Applications built against
// UIKit-for-Mac bind them to AppKit, so AppKit has to export them. The weight
// numbers are the old float32-rounded values in tree since cdc08795, origin
// unrecorded (VibeDarling/darling#1498); the decimals here round them. Kept as
// GUESS, NEEDS-REAL-MAC (valid range -1.0 to 1.0, 0.0 is regular: rung 3,
// NSFontDescriptor.TraitKey.weight). The string
// constants carry the same literals as their NS counterparts so that a
// descriptor built with either name is read the same way.
APPKIT_EXPORT const CGFloat UIFontWeightUltraLight;
APPKIT_EXPORT const CGFloat UIFontWeightThin;
APPKIT_EXPORT const CGFloat UIFontWeightLight;
APPKIT_EXPORT const CGFloat UIFontWeightRegular;
APPKIT_EXPORT const CGFloat UIFontWeightMedium;
APPKIT_EXPORT const CGFloat UIFontWeightSemibold;
APPKIT_EXPORT const CGFloat UIFontWeightBold;
APPKIT_EXPORT const CGFloat UIFontWeightHeavy;
APPKIT_EXPORT const CGFloat UIFontWeightBlack;

const CGFloat UIFontWeightUltraLight = -0.8;
const CGFloat UIFontWeightThin = -0.6;
const CGFloat UIFontWeightLight = -0.4;
const CGFloat UIFontWeightRegular = 0.0;
const CGFloat UIFontWeightMedium = 0.23;
const CGFloat UIFontWeightSemibold = 0.3;
const CGFloat UIFontWeightBold = 0.4;
const CGFloat UIFontWeightHeavy = 0.56;
const CGFloat UIFontWeightBlack = 0.62;

APPKIT_EXPORT NSFontDescriptorAttributeName const UIFontDescriptorTraitsAttribute;
APPKIT_EXPORT NSFontDescriptorAttributeName const UIFontDescriptorFeatureSettingsAttribute;
APPKIT_EXPORT NSFontDescriptorAttributeName const UIFontDescriptorTextStyleAttribute;
APPKIT_EXPORT NSFontDescriptorFeatureKey const UIFontFeatureTypeIdentifierKey;
APPKIT_EXPORT NSFontDescriptorFeatureKey const UIFontFeatureSelectorIdentifierKey;
APPKIT_EXPORT NSFontDescriptorTraitKey const UIFontWeightTrait;
APPKIT_EXPORT NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignSerif;
APPKIT_EXPORT NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignRounded;

NSFontDescriptorAttributeName const UIFontDescriptorTraitsAttribute = @"NSCTFontTraitsAttribute";
NSFontDescriptorAttributeName const UIFontDescriptorFeatureSettingsAttribute = @"NSCTFontFeatureSettingsAttribute";
NSFontDescriptorAttributeName const UIFontDescriptorTextStyleAttribute = @"UIFontDescriptorTextStyleAttribute";
NSFontDescriptorFeatureKey const UIFontFeatureTypeIdentifierKey = @"CTFeatureTypeIdentifier";
NSFontDescriptorFeatureKey const UIFontFeatureSelectorIdentifierKey = @"CTFeatureSelectorIdentifier";
NSFontDescriptorTraitKey const UIFontWeightTrait = @"NSCTFontWeightTrait";
NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignSerif = @"NSCTFontUIFontDesignSerif";
NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignRounded = @"NSCTFontUIFontDesignRounded";
