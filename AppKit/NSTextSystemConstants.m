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
// found in AppKit. Values are the same as UIFoundation's (tests/attribute-name-source-agree.rb checks the pairs); the
// attribute names the stand-in exports and AppKit re-exports (NSFont, NSColor, ... NSObliqueness) are defined only there.

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
// Attribute names only AppKit defines (nothing in the UIFoundation stand-in does): Journal and TV bind them to AppKit. Values:
// observed on a real Mac (macOS 26.1, mac-probe/darling_probe_a1.txt lines 80 and 81), rung 4.
NSAttributedStringKey NSParagraphAttachmentAttributeName = @"NSTextParagraphAnchoredAttachment";
NSAttributedStringKey NSTextEncapsulationAttributeName = @"NSTextEncapsulation";
NSAttributedStringKey NSBaselineOffsetAttributeName = @"NSBaselineOffset";
NSAttributedStringKey NSCursorAttributeName = @"NSCursor";
NSFontDescriptorSystemDesign const NSFontDescriptorSystemDesignRounded = @"NSCTFontUIFontDesignRounded";
NSFontDescriptorAttributeName NSFontFamilyAttribute = @"NSFontFamilyAttribute";
NSFontDescriptorAttributeName NSFontNameAttribute = @"NSFontNameAttribute";
// GUESS (no permitted source): Apple's documentation names these constants but lists no string value. Each carries its
// own name. Only code that compares them against these same objects works. On the cache stage the cache's UIFoundation
// presumably can only match a text style against its own literals, so a guessed value probably does not match there and a
// lookup by text style would miss silently (nil). The real values need a real Mac.
NSFontTextStyle const NSFontTextStyleBody = @"NSFontTextStyleBody";
NSFontTextStyle const NSFontTextStyleCallout = @"NSFontTextStyleCallout";
NSFontTextStyle const NSFontTextStyleCaption1 = @"NSFontTextStyleCaption1";
NSFontTextStyle const NSFontTextStyleCaption2 = @"NSFontTextStyleCaption2";
NSFontTextStyle const NSFontTextStyleFootnote = @"NSFontTextStyleFootnote";
NSFontTextStyle const NSFontTextStyleHeadline = @"NSFontTextStyleHeadline";
NSFontTextStyle const NSFontTextStyleLargeTitle = @"NSFontTextStyleLargeTitle";
NSFontTextStyle const NSFontTextStyleSubheadline = @"NSFontTextStyleSubheadline";
NSFontTextStyle const NSFontTextStyleTitle1 = @"NSFontTextStyleTitle1";
NSFontTextStyle const NSFontTextStyleTitle2 = @"NSFontTextStyleTitle2";
NSFontTextStyle const NSFontTextStyleTitle3 = @"NSFontTextStyleTitle3";
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
NSAttributedStringKey NSKernAttributeName = @"NSKern";
NSAttributedStringKey NSLigatureAttributeName = @"NSLigature";
NSAttributedStringKey NSLinkAttributeName = @"NSLink";
NSAttributedStringKey NSMarkedClauseSegmentAttributeName = @"NSMarkedClauseSegment";
NSAttributedStringKey NSShadowAttributeName = @"NSShadow";
NSAttributedStringKey NSStrikethroughStyleAttributeName = @"NSStrikethrough";
NSString *const NSTextContentStorageUnsupportedAttributeAddedNotification =
        @"NSTextContentStorageUnsupportedAttributeAddedNotification";
NSString *const NSTextListMarkerDecimal = @"{decimal}";
NSString *const NSTextListMarkerDisc = @"{disc}";
NSAttributedStringKey NSToolTipAttributeName = @"NSToolTip";
NSAttributedStringDocumentReadingOptionKey const NSTextKit1ListMarkerFormatDocumentOption =
        @"NSTextKit1ListMarkerFormatDocumentOption";
