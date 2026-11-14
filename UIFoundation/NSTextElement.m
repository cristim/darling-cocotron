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
#import <AppKit/NSTextList.h>
#import <AppKit/NSTextRange.h>

// GUESS (not in the public documentation, not observed): an element made here is not in any layout
// (isRepresentedElement is NO), has no parent and no children. Nothing in this tree builds an element tree, so no
// other answer would be true of any element a client can obtain.
@implementation NSTextElement {
    id _textContentManager; // weak (objc_storeWeak), as in Apple's header
    NSTextRange *_elementRange;
}

- (instancetype) initWithTextContentManager: (NSTextContentManager *) textContentManager {
    if ((self = [super init]))
        objc_storeWeak(&_textContentManager, textContentManager);
    return self;
}

- (void) dealloc {
    objc_storeWeak(&_textContentManager, nil);
    [_elementRange release];
    [super dealloc];
}

- (NSTextContentManager *) textContentManager {
    return objc_loadWeak(&_textContentManager);
}

- (void) setTextContentManager: (NSTextContentManager *) textContentManager {
    objc_storeWeak(&_textContentManager, textContentManager);
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

// GUESS (not in the public documentation, not observed): the factory with children and a nesting level raises, an
// element's children keep no link back to it (the parent is only what the initializer was given), and a nil contents
// is an empty paragraph.
@implementation NSTextListElement {
    id _parentElement; // weak (objc_storeWeak), as in Apple's header
    NSTextList *_textList;
    NSAttributedString *_contents;
    NSDictionary *_markerAttributes;
    NSArray *_childElements;
}

- (instancetype) initWithParentElement: (NSTextListElement *) parent
                              textList: (NSTextList *) textList
                              contents: (NSAttributedString *) contents
                      markerAttributes: (NSDictionary *) markerAttributes
                         childElements: (NSArray *) children
{
    if ((self = [super initWithAttributedString: contents])) {
        objc_storeWeak(&_parentElement, parent);
        _textList = [textList retain];
        _contents = [contents copy];
        _markerAttributes = [markerAttributes copy];
        _childElements = [(children ?: [NSArray array]) copy];
    }
    return self;
}

- (instancetype) initWithAttributedString: (NSAttributedString *) attributedString {
    [self release];
    [NSException raise: NSInvalidArgumentException
                format: @"-[NSTextListElement initWithAttributedString:]: use initWithParentElement:textList:contents:markerAttributes:childElements:"];
    return nil;
}

+ (instancetype) textListElementWithContents: (NSAttributedString *) contents
                            markerAttributes: (NSDictionary *) markerAttributes
                                    textList: (NSTextList *) textList
                               childElements: (NSArray *) children
{
    return [[[self alloc] initWithParentElement: nil
                                       textList: textList
                                       contents: contents
                               markerAttributes: markerAttributes
                                  childElements: children] autorelease];
}

+ (instancetype) textListElementWithChildElements: (NSArray *) children
                                         textList: (NSTextList *) textList
                                     nestingLevel: (NSInteger) nestingLevel
{
    [NSException raise: NSInvalidArgumentException
                format: @"+[NSTextListElement textListElementWithChildElements:textList:nestingLevel:] is not implemented: "
                         "the documentation does not say what the nesting level does"];
    return nil;
}

- (void) dealloc {
    objc_storeWeak(&_parentElement, nil);
    [_textList release];
    [_contents release];
    [_markerAttributes release];
    [_childElements release];
    [super dealloc];
}

- (NSTextList *) textList {
    return _textList;
}

- (NSAttributedString *) contents {
    return _contents;
}

- (NSDictionary *) markerAttributes {
    return _markerAttributes;
}

- (NSTextListElement *) parentElement {
    return objc_loadWeak(&_parentElement);
}

- (NSArray *) childElements {
    return _childElements;
}

- (NSAttributedString *) attributedString {
    [NSException raise: NSInvalidArgumentException
                format: @"-[NSTextListElement attributedString] is not implemented: this tree has no list marker layout"];
    return nil;
}

@end
