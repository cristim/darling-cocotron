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

#import "UIFAppKit.h"
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSLayoutManager.h>
#import <AppKit/NSTextContainer.h>
#import <AppKit/NSTextLineFragment.h>
#import <AppKit/NSTextStorage.h>

// A line fragment is a single line of the attributed string's range, laid out by a private TextKit 1 layout manager
// in a container wide enough never to wrap (there is no TextKit 2 line layout in this tree). The public
// documentation gives the properties and methods, not the coordinate conventions, so these are guesses.
//
// GUESS (not in the public documentation, not observed): the line fragment coordinate system is flipped (y grows
// downward) with the origin at the top-left of the line: typographicBounds has its origin at (0, 0), the width of the
// laid out glyphs and the height of the line (the TextKit 1 line fragment rect with font leading); glyphOrigin is
// the baseline origin of the first glyph, (0, baseline offset); locationForCharacterAtIndex: is the baseline origin
// of that character's glyph in the same coordinates; the character indexes of the last three methods are indexes
// into attributedString (inside characterRange), not into the range; characterIndexForPoint: clamps a point outside
// the line to the first or last character of the range; fractionOfDistanceThroughGlyphForPoint: is the fraction that
// TextKit 1 reports for the glyph under the point. Only the first line of the range is laid out, measured and drawn (an index on a later line raises NSRangeException); -initWithCoder: fails
// loudly (the archive format is not documented, and nothing here writes one).
@implementation NSTextLineFragment {
    NSAttributedString *_attributedString;
    NSRange _characterRange;
    NSTextStorage *_storage;
    NSLayoutManager *_layoutManager;
    NSTextContainer *_container;
    CGRect _typographicBounds;
    CGPoint _glyphOrigin;
    NSRange _lineGlyphs;  // the glyphs of the first line of the range
    NSRange _lineChars;   // their characters, relative to the range
    NSRect _lineRect;     // the first line's used rectangle
}

- (instancetype) initWithCoder: (NSCoder *) aDecoder {
    [self release];
    [NSException raise: NSInvalidArgumentException
                format: @"-[NSTextLineFragment initWithCoder:] is not implemented: this tree has no text line fragment archive"];
    return nil;
}

- (instancetype) initWithAttributedString: (NSAttributedString *) attributedString range: (NSRange) range {
    if (NSMaxRange(range) > [attributedString length]) {
        [self release];
        [NSException raise: NSRangeException
                    format: @"-[NSTextLineFragment initWithAttributedString:range:]: range %@ is beyond the string of length %lu",
                            NSStringFromRange(range), (unsigned long) [attributedString length]];
    }
    if ((self = [super init])) {
        _attributedString = [attributedString copy];
        _characterRange = range;
        _storage = [[NSTextStorage alloc] initWithAttributedString:
                            [_attributedString attributedSubstringFromRange: range]];
        _layoutManager = [[NSLayoutManager alloc] init];
        _container = [[NSTextContainer alloc] initWithContainerSize: NSMakeSize(1.0e7, 1.0e7)];
        [_container setLineFragmentPadding: 0];
        [_layoutManager addTextContainer: _container];
        [_storage addLayoutManager: _layoutManager];
        [_layoutManager ensureLayoutForTextContainer: _container];
        if ([_layoutManager numberOfGlyphs] > 0) {
            _lineRect = [_layoutManager lineFragmentUsedRectForGlyphAtIndex: 0 effectiveRange: &_lineGlyphs];
            _lineChars = [_layoutManager characterRangeForGlyphRange: _lineGlyphs actualGlyphRange: NULL];
            _typographicBounds = CGRectMake(0, 0, _lineRect.size.width, _lineRect.size.height);
            _glyphOrigin = CGPointMake(0, [_layoutManager locationForGlyphAtIndex: 0].y);
        }
    }
    return self;
}

- (instancetype) initWithString: (NSString *) string
                     attributes: (NSDictionary<NSString *, id> *) attributes
                          range: (NSRange) range
{
    NSAttributedString *attributed = [[[NSAttributedString alloc] initWithString: string attributes: attributes] autorelease];
    return [self initWithAttributedString: attributed range: range];
}

- (void) dealloc {
    [_storage removeLayoutManager: _layoutManager];
    [_attributedString release];
    [_storage release];
    [_layoutManager release];
    [_container release];
    [super dealloc];
}

- (NSAttributedString *) attributedString {
    return _attributedString;
}

- (NSRange) characterRange {
    return _characterRange;
}

- (CGRect) typographicBounds {
    return _typographicBounds;
}

- (CGPoint) glyphOrigin {
    return _glyphOrigin;
}

// Draws only the first line of the range. The previous current graphics context, which may be none, is current again
// afterwards: +saveGraphicsState and +restoreGraphicsState push nothing when no context is current.
- (void) drawAtPoint: (CGPoint) point inContext: (CGContextRef) context {
    Class graphicsContext = UIFAppKitClass(NSGraphicsContext);
    id previous = [[graphicsContext currentContext] retain];
    @try {
        [graphicsContext setCurrentContext: [graphicsContext graphicsContextWithCGContext: context flipped: YES]];
        [_layoutManager drawBackgroundForGlyphRange: _lineGlyphs atPoint: NSPointFromCGPoint(point)];
        [_layoutManager drawGlyphsForGlyphRange: _lineGlyphs atPoint: NSPointFromCGPoint(point)];
    } @finally {
        [graphicsContext setCurrentContext: previous];
        [previous release];
    }
}

- (CGPoint) locationForCharacterAtIndex: (NSInteger) index {
    if (index < (NSInteger) _characterRange.location || index > (NSInteger) NSMaxRange(_characterRange))
        [NSException raise: NSRangeException
                    format: @"-[NSTextLineFragment locationForCharacterAtIndex:]: index %ld is outside the character range %@",
                            (long) index, NSStringFromRange(_characterRange)];
    NSUInteger local = (NSUInteger) index - _characterRange.location;
    if ([_layoutManager numberOfGlyphs] == 0)
        return CGPointMake(0, _glyphOrigin.y);
    if (local > NSMaxRange(_lineChars))
        [NSException raise: NSRangeException
                    format: @"-[NSTextLineFragment locationForCharacterAtIndex:]: index %ld is not on this line fragment, "
                             "which holds the first line of %@",
                            (long) index, NSStringFromRange(_characterRange)];
    if (local == NSMaxRange(_lineChars))
        return CGPointMake(NSMaxX(_lineRect), _glyphOrigin.y);
    NSUInteger glyph = [_layoutManager glyphIndexForCharacterAtIndex: local];
    // locationForGlyphAtIndex: is only set for the first glyph of a run; the glyph's own origin is its bounding box.
    NSRect glyphBox = [_layoutManager boundingRectForGlyphRange: NSMakeRange(glyph, 1) inTextContainer: _container];
    return CGPointMake(NSMinX(glyphBox), _glyphOrigin.y);
}

// The index of the last character of the first line that is not its paragraph separator.
- (NSUInteger) _lastLineCharacter {
    NSUInteger contentsEnd = 0;
    [[_storage string] getLineStart: NULL end: NULL contentsEnd: &contentsEnd
                           forRange: NSMakeRange(_lineChars.location, 0)];
    return contentsEnd > _lineChars.location ? contentsEnd - 1 : _lineChars.location;
}

- (NSInteger) characterIndexForPoint: (CGPoint) point {
    if ([_layoutManager numberOfGlyphs] == 0)
        return (NSInteger) _characterRange.location;
    NSUInteger local;
    if (point.x <= 0)
        local = _lineChars.location;
    else if (point.x >= _typographicBounds.size.width)
        local = [self _lastLineCharacter];
    else {
        CGFloat fraction;
        NSUInteger glyph = [_layoutManager glyphIndexForPoint: NSMakePoint(point.x, NSMidY(_lineRect))
                                              inTextContainer: _container
                               fractionOfDistanceThroughGlyph: &fraction];
        glyph = MIN(MAX(glyph, _lineGlyphs.location), NSMaxRange(_lineGlyphs) - 1);
        local = [_layoutManager characterIndexForGlyphAtIndex: glyph];
    }
    return (NSInteger) (_characterRange.location + local);
}

- (CGFloat) fractionOfDistanceThroughGlyphForPoint: (CGPoint) point {
    if ([_layoutManager numberOfGlyphs] == 0)
        return 0;
    return [_layoutManager fractionOfDistanceThroughGlyphForPoint: NSMakePoint(point.x, NSMidY(_lineRect))
                                                  inTextContainer: _container];
}

@end
