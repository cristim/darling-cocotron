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
// UIKit-for-Mac bind them to AppKit, so AppKit has to export them. Weights are
// the decimal values the NSFontWeight bit patterns above decode to, and the
// string constants carry the same literals as their NS counterparts so that a
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

APPKIT_EXPORT NSFontDescriptorAttributeName UIFontDescriptorTraitsAttribute;
APPKIT_EXPORT NSFontDescriptorAttributeName UIFontDescriptorFeatureSettingsAttribute;
APPKIT_EXPORT NSFontDescriptorAttributeName UIFontDescriptorTextStyleAttribute;
APPKIT_EXPORT NSFontDescriptorFeatureKey UIFontFeatureTypeIdentifierKey;
APPKIT_EXPORT NSFontDescriptorFeatureKey UIFontFeatureSelectorIdentifierKey;
APPKIT_EXPORT NSFontDescriptorTraitKey UIFontWeightTrait;
APPKIT_EXPORT NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignDefault;
APPKIT_EXPORT NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignSerif;
APPKIT_EXPORT NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignMonospaced;
APPKIT_EXPORT NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignRounded;

NSFontDescriptorAttributeName UIFontDescriptorTraitsAttribute = @"NSCTFontTraitsAttribute";
NSFontDescriptorAttributeName UIFontDescriptorFeatureSettingsAttribute = @"NSCTFontFeatureSettingsAttribute";
NSFontDescriptorAttributeName UIFontDescriptorTextStyleAttribute = @"UIFontDescriptorTextStyleAttribute";
NSFontDescriptorFeatureKey UIFontFeatureTypeIdentifierKey = @"CTFeatureTypeIdentifier";
NSFontDescriptorFeatureKey UIFontFeatureSelectorIdentifierKey = @"CTFeatureSelectorIdentifier";
NSFontDescriptorTraitKey UIFontWeightTrait = @"NSCTFontWeightTrait";
NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignDefault = @"NSCTFontUIFontDesignDefault";
NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignSerif = @"NSCTFontUIFontDesignSerif";
NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignMonospaced = @"NSCTFontUIFontDesignMonospaced";
NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignRounded = @"NSCTFontUIFontDesignRounded";
