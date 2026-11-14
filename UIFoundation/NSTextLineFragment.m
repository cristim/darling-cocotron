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
// TextKit 1 reports for the glyph under the point. The first line of the range is laid out; -initWithCoder: fails
// loudly (the archive format is not documented, and nothing here writes one).
@implementation NSTextLineFragment {
    NSAttributedString *_attributedString;
    NSRange _characterRange;
    NSTextStorage *_storage;
    NSLayoutManager *_layoutManager;
    NSTextContainer *_container;
    CGRect _typographicBounds;
    CGPoint _glyphOrigin;
}

- (instancetype) initWithCoder: (NSCoder *) aDecoder {
    [self release];
    [NSException raise: NSInvalidArgumentException
                format: @"-[NSTextLineFragment initWithCoder:] is not implemented: this tree has no text line fragment archive"];
    return nil;
}

- (instancetype) initWithAttributedString: (NSAttributedString *) attributedString range: (NSRange) range {
    if (NSMaxRange(range) > [attributedString length])
        [NSException raise: NSRangeException
                    format: @"-[NSTextLineFragment initWithAttributedString:range:]: range %@ is beyond the string of length %lu",
                            NSStringFromRange(range), (unsigned long) [attributedString length]];
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
            NSRect used = [_layoutManager lineFragmentUsedRectForGlyphAtIndex: 0 effectiveRange: NULL];
            _typographicBounds = CGRectMake(0, 0, used.size.width, used.size.height);
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

- (void) drawAtPoint: (CGPoint) point inContext: (CGContextRef) context {
    Class graphicsContext = UIFAppKitClass(NSGraphicsContext);
    [graphicsContext saveGraphicsState];
    [graphicsContext setCurrentContext: [graphicsContext graphicsContextWithCGContext: context flipped: YES]];
    NSRange glyphs = NSMakeRange(0, [_layoutManager numberOfGlyphs]);
    [_layoutManager drawBackgroundForGlyphRange: glyphs atPoint: NSPointFromCGPoint(point)];
    [_layoutManager drawGlyphsForGlyphRange: glyphs atPoint: NSPointFromCGPoint(point)];
    [graphicsContext restoreGraphicsState];
}

- (CGPoint) locationForCharacterAtIndex: (NSInteger) index {
    if (index < (NSInteger) _characterRange.location || index > (NSInteger) NSMaxRange(_characterRange))
        [NSException raise: NSRangeException
                    format: @"-[NSTextLineFragment locationForCharacterAtIndex:]: index %ld is outside the character range %@",
                            (long) index, NSStringFromRange(_characterRange)];
    NSUInteger glyphCount = [_layoutManager numberOfGlyphs];
    NSUInteger local = (NSUInteger) index - _characterRange.location;
    if (glyphCount == 0)
        return CGPointMake(0, _glyphOrigin.y);
    if (local >= glyphCount)
        return CGPointMake(NSMaxX([_layoutManager lineFragmentUsedRectForGlyphAtIndex: glyphCount - 1 effectiveRange: NULL]),
                           _glyphOrigin.y);
    NSUInteger glyph = [_layoutManager glyphIndexForCharacterAtIndex: local];
    // locationForGlyphAtIndex: is only set for the first glyph of a run; the glyph's own origin is its bounding box.
    NSRect glyphBox = [_layoutManager boundingRectForGlyphRange: NSMakeRange(glyph, 1) inTextContainer: _container];
    return CGPointMake(NSMinX(glyphBox), _glyphOrigin.y);
}

- (NSInteger) characterIndexForPoint: (CGPoint) point {
    if ([_layoutManager numberOfGlyphs] == 0)
        return (NSInteger) _characterRange.location;
    NSUInteger glyphCount = [_layoutManager numberOfGlyphs];
    NSUInteger glyph;
    if (point.x <= 0)
        glyph = 0;
    else if (point.x >= _typographicBounds.size.width)
        glyph = glyphCount - 1;
    else
    {
        CGFloat fraction;
        glyph = MIN([_layoutManager glyphIndexForPoint: NSPointFromCGPoint(point)
                                       inTextContainer: _container
                        fractionOfDistanceThroughGlyph: &fraction],
                    glyphCount - 1);
    }
    return (NSInteger) (_characterRange.location + [_layoutManager characterIndexForGlyphAtIndex: glyph]);
}

- (CGFloat) fractionOfDistanceThroughGlyphForPoint: (CGPoint) point {
    if ([_layoutManager numberOfGlyphs] == 0)
        return 0;
    return [_layoutManager fractionOfDistanceThroughGlyphForPoint: NSPointFromCGPoint(point)
                                                  inTextContainer: _container];
}

@end
