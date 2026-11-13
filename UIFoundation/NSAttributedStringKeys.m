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
NSAttributedStringKey NSForegroundColorAttributeName = @"NSForegroundColorAttributeName";
NSAttributedStringKey NSBackgroundColorAttributeName = @"NSBackgroundColorAttributeName";
NSAttributedStringKey NSUnderlineStyleAttributeName = @"NSUnderlineStyleAttributeName";
NSAttributedStringKey NSUnderlineColorAttributeName = @"NSUnderlineColorAttributeName";
NSAttributedStringKey NSAttachmentAttributeName = @"NSAttachmentAttributeName";
NSAttributedStringKey NSKernAttributeName = @"NSKernAttributeName";
NSAttributedStringKey NSLigatureAttributeName = @"NSLigatureAttributeName";
NSAttributedStringKey NSStrikethroughStyleAttributeName = @"NSStrikethroughStyleAttributeName";
NSAttributedStringKey NSStrikethroughColorAttributeName = @"NSStrikethroughColorAttributeName";
NSAttributedStringKey NSObliquenessAttributeName = @"NSObliquenessAttributeName";
NSAttributedStringKey NSStrokeWidthAttributeName = @"NSStrokeWidthAttributeName";
NSAttributedStringKey NSStrokeColorAttributeName = @"NSStrokeColorAttributeName";
NSAttributedStringKey NSBaselineOffsetAttributeName = @"NSBaselineOffsetAttributeName";
NSAttributedStringKey NSSuperscriptAttributeName = @"NSSuperScript";
NSAttributedStringKey NSLinkAttributeName = @"NSLinkAttributeName";
NSAttributedStringKey NSShadowAttributeName = @"NSShadowAttributeName";
NSAttributedStringKey NSExpansionAttributeName = @"NSExpansionAttributeName";
NSAttributedStringKey NSCursorAttributeName = @"NSCursorAttributeName";
NSAttributedStringKey NSMarkedClauseSegmentAttributeName = @"NSMarkedClauseSegment";
NSAttributedStringKey NSToolTipAttributeName = @"NSToolTipAttributeName";
NSAttributedStringKey NSGlyphInfoAttributeName = @"NSGlyphInfo";
NSAttributedStringKey NSVerticalGlyphFormAttributeName = @"NSVerticalGlyphForm";
NSAttributedStringKey NSTextAlternativesAttributeName = @"NSTextAlternatives";
NSAttributedStringKey NSSpellingStateAttributeName = @"NSSpellingStateAttributeName"; // temporary attribute
