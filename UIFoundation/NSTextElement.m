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
#import <AppKit/NSTextContentManager.h>
#import <AppKit/NSTextElement.h>
#import <AppKit/NSTextRange.h>

// GUESS (not in the public documentation, not observed): an element made here is not in any layout
// (isRepresentedElement is NO), has no parent and no children. Nothing in this tree builds an element tree, so no
// other answer would be true of any element a client can obtain.
@implementation NSTextElement {
    NSTextContentManager *_textContentManager; // weak in Apple's header; not retained here, like NSTextKit2.m
    NSTextRange *_elementRange;
}

- (instancetype) initWithTextContentManager: (NSTextContentManager *) textContentManager {
    if ((self = [super init]))
        _textContentManager = textContentManager;
    return self;
}

- (void) dealloc {
    [_elementRange release];
    [super dealloc];
}

- (NSTextContentManager *) textContentManager {
    return _textContentManager;
}

- (void) setTextContentManager: (NSTextContentManager *) textContentManager {
    _textContentManager = textContentManager;
}

- (NSTextRange *) elementRange {
    return _elementRange;
}

- (void) setElementRange: (NSTextRange *) elementRange {
    [elementRange retain];
    [_elementRange release];
    _elementRange = elementRange;
}

- (NSTextElement *) parentElement {
    return nil;
}

- (NSArray *) childElements {
    return [NSArray array];
}

- (BOOL) isRepresentedElement {
    return NO;
}

@end

// The paragraph's two ranges are its element range split at the end of its content: what
// -getParagraphStart:end:contentsEnd:forRange: reports for the attributed string says where the separator starts.
// Nothing here is documented beyond "the range of the paragraph" and "the range of the paragraph separator" in the
// containing text's attributed string. GUESS (not in the public documentation, not observed): the separator range is
// nil, not empty, when the paragraph has no separator (the property is nullable); the content range of an empty
// paragraph is empty at the start of the element range.
@implementation NSTextParagraph {
    NSAttributedString *_attributedString;
}

- (instancetype) initWithAttributedString: (NSAttributedString *) attributedString {
    if ((self = [super initWithTextContentManager: nil]))
        _attributedString = [(attributedString ?: [[[NSAttributedString alloc] init] autorelease]) copy];
    return self;
}

- (void) dealloc {
    [_attributedString release];
    [super dealloc];
}

- (NSAttributedString *) attributedString {
    return _attributedString;
}

- (NSUInteger) _contentLength {
    NSUInteger contentsEnd = 0;
    [[_attributedString string] getParagraphStart: NULL
                                              end: NULL
                                      contentsEnd: &contentsEnd
                                         forRange: NSMakeRange(0, 0)];
    return contentsEnd;
}

- (NSTextRange *) _rangeFromOffset: (NSUInteger) from toOffset: (NSUInteger) to {
    NSTextRange *element = [self elementRange];
    NSTextContentManager *manager = [self textContentManager];
    if (element == nil || manager == nil)
        return nil;
    id<NSTextLocation> start = [manager locationFromLocation: [element location] withOffset: from];
    id<NSTextLocation> end = [manager locationFromLocation: [element location] withOffset: to];
    if (start == nil || end == nil)
        return nil;
    return [[[NSTextRange alloc] initWithLocation: start endLocation: end] autorelease];
}

- (NSTextRange *) paragraphContentRange {
    return [self _rangeFromOffset: 0 toOffset: [self _contentLength]];
}

- (NSTextRange *) paragraphSeparatorRange {
    NSUInteger contentLength = [self _contentLength];
    if (contentLength >= [_attributedString length])
        return nil;
    return [self _rangeFromOffset: contentLength toOffset: [_attributedString length]];
}

@end

@implementation NSTextListElement
@end
