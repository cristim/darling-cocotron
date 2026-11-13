/*
 This file is part of Darling.

 Copyright (C) 2026 Darling developers

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

// Constants that macOS defines in AppKit and that guest apps bind to AppKit. UIFoundation's own copies (it cannot import
// AppKit) are not exported (UIFoundation/unexported-symbols.txt), so when another UIFoundation is in use these are still
// found in AppKit. Values are the same as UIFoundation's.

#import <AppKit/NSAdaptiveImageGlyph.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontDescriptor.h>
#import <AppKit/NSTextContentManager.h>
#import <AppKit/NSTextList.h>
#import <AppKit/NSTextTab.h>

NSAttributedStringKey const NSAdaptiveImageGlyphAttributeName = @"NSAdaptiveImageGlyph";
NSNotificationName NSAntialiasThresholdChangedNotification =
        @"NSAntialiasThresholdChangedNotification";
NSAttributedStringKey NSBaselineOffsetAttributeName = @"NSBaselineOffsetAttributeName";
NSAttributedStringKey NSCursorAttributeName = @"NSCursorAttributeName";
NSFontDescriptorSystemDesign const NSFontDescriptorSystemDesignRounded = @"NSCTFontUIFontDesignRounded";
NSFontDescriptorAttributeName NSFontFamilyAttribute = @"NSFontFamilyAttribute";
NSFontDescriptorAttributeName NSFontNameAttribute = @"NSFontNameAttribute";
NSFontDescriptorAttributeName NSFontTraitsAttribute = @"NSCTFontTraitsAttribute";
const NSFontWeight NSFontWeightBlack = 0x3fe3d70a40000000;
const NSFontWeight NSFontWeightBold = 0x3fd99999a0000000;
const NSFontWeight NSFontWeightHeavy = 0x3fe1eb8520000000;
const NSFontWeight NSFontWeightLight = 0xbfd99999a0000000;
const NSFontWeight NSFontWeightMedium = 0x3fcd70a3e0000000;
const NSFontWeight NSFontWeightRegular = 0x0000000000000000;
const NSFontWeight NSFontWeightSemibold = 0x3fd3333340000000;
const NSFontWeight NSFontWeightThin = 0xbfe3333340000000;
NSFontDescriptorTraitKey NSFontWeightTrait = @"NSCTFontWeightTrait";
const NSFontWeight NSFontWeightUltraLight = 0xbfe99999a0000000;
NSAttributedStringKey NSGlyphInfoAttributeName = @"NSGlyphInfo";
NSAttributedStringKey NSKernAttributeName = @"NSKernAttributeName";
NSAttributedStringKey NSLigatureAttributeName = @"NSLigatureAttributeName";
NSAttributedStringKey NSLinkAttributeName = @"NSLinkAttributeName";
NSAttributedStringKey NSMarkedClauseSegmentAttributeName = @"NSMarkedClauseSegment";
NSAttributedStringKey NSShadowAttributeName = @"NSShadowAttributeName";
NSAttributedStringKey NSStrikethroughStyleAttributeName = @"NSStrikethroughStyleAttributeName";
NSString *const NSTextContentStorageUnsupportedAttributeAddedNotification =
        @"NSTextContentStorageUnsupportedAttributeAddedNotification";
NSString *const NSTextListMarkerDecimal = @"{decimal}";
NSString *const NSTextListMarkerDisc = @"{disc}";
NSAttributedStringKey NSToolTipAttributeName = @"NSToolTipAttributeName";
NSAttributedStringDocumentReadingOptionKey const NSTextKit1ListMarkerFormatDocumentOption =
        @"NSTextKit1ListMarkerFormatDocumentOption";
