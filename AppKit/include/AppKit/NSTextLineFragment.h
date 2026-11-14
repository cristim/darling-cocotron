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

// A line fragment of a TextKit 2 layout fragment (macOS 12), declared as the public documentation spells it. It is
// laid out with a TextKit 1 NSLayoutManager on a single line without wrapping; see UIFoundation/NSTextLineFragment.m.

#import <AppKit/AppKitExport.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@interface NSTextLineFragment : NSObject

- (instancetype) initWithAttributedString: (NSAttributedString *) attributedString range: (NSRange) range;
- (instancetype) initWithString: (NSString *) string
                     attributes: (NSDictionary<NSString *, id> *) attributes
                          range: (NSRange) range;
- (nullable instancetype) initWithCoder: (NSCoder *) aDecoder;

@property(readonly, strong) NSAttributedString *attributedString;
@property(readonly) NSRange characterRange;
@property(readonly) CGRect typographicBounds;
@property(readonly) CGPoint glyphOrigin;

- (void) drawAtPoint: (CGPoint) point inContext: (CGContextRef) context;
- (CGPoint) locationForCharacterAtIndex: (NSInteger) index;
- (NSInteger) characterIndexForPoint: (CGPoint) point;
- (CGFloat) fractionOfDistanceThroughGlyphForPoint: (CGPoint) point;

@end
