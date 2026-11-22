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

// The attribute names of NSAttributedString. UIFoundation's text classes use
// them, so they are defined there and AppKit re-exports them.

#import <AppKit/NSAttributedString.h>

// Font, paragraph style and superscript use the key strings archived attributed strings carry, as CoreText's
// kCTFontAttributeName and kCTParagraphStyleAttributeName do.
NSAttributedStringKey NSFontAttributeName = @"NSFont";
NSAttributedStringKey NSParagraphStyleAttributeName = @"NSParagraphStyle";
NSAttributedStringKey NSForegroundColorAttributeName = @"NSColor";
NSAttributedStringKey NSBackgroundColorAttributeName = @"NSBackgroundColor";
NSAttributedStringKey NSUnderlineStyleAttributeName = @"NSUnderline";
NSAttributedStringKey NSUnderlineColorAttributeName = @"NSUnderlineColor";
NSAttributedStringKey NSAttachmentAttributeName = @"NSAttachment";
NSAttributedStringKey NSKernAttributeName = @"NSKern";
NSAttributedStringKey NSLigatureAttributeName = @"NSLigature";
NSAttributedStringKey NSStrikethroughStyleAttributeName = @"NSStrikethrough";
NSAttributedStringKey NSStrikethroughColorAttributeName = @"NSStrikethroughColor";
NSAttributedStringKey NSObliquenessAttributeName = @"NSObliqueness";
NSAttributedStringKey NSStrokeWidthAttributeName = @"NSStrokeWidth";
NSAttributedStringKey NSStrokeColorAttributeName = @"NSStrokeColor";
NSAttributedStringKey NSBaselineOffsetAttributeName = @"NSBaselineOffset";
NSAttributedStringKey NSSuperscriptAttributeName = @"NSSuperScript";
NSAttributedStringKey NSLinkAttributeName = @"NSLink";
NSAttributedStringKey NSShadowAttributeName = @"NSShadow";
NSAttributedStringKey NSExpansionAttributeName = @"NSExpansion";
NSAttributedStringKey NSCursorAttributeName = @"NSCursor";
NSAttributedStringKey NSMarkedClauseSegmentAttributeName = @"NSMarkedClauseSegment";
NSAttributedStringKey NSToolTipAttributeName = @"NSToolTip";
NSAttributedStringKey NSGlyphInfoAttributeName = @"NSGlyphInfo";
NSAttributedStringKey NSVerticalGlyphFormAttributeName = @"CTVerticalForms";
NSAttributedStringKey NSTextAlternativesAttributeName = @"NSTextAlternatives";
NSAttributedStringKey NSSpellingStateAttributeName = @"NSSpellingState"; // temporary attribute
