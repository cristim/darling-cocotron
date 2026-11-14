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

// TextKit 2 text elements (macOS 12), declared as the public documentation spells them. Nothing in this tree creates
// elements: the content storage keeps an NSTextStorage and has no element tree (see NSTextContentManager.h), so
// an element has no children and no parent here and is never "represented".

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>

@class NSTextContentManager, NSTextRange;

@interface NSTextElement : NSObject

- (instancetype) initWithTextContentManager: (NSTextContentManager *) textContentManager;

@property(weak, nullable) NSTextContentManager *textContentManager;
@property(strong, nullable) NSTextRange *elementRange;
@property(readonly, weak, nullable) NSTextElement *parentElement;
@property(readonly, copy) NSArray<__kindof NSTextElement *> *childElements;
@property(readonly) BOOL isRepresentedElement;

@end

// A paragraph backed by an attributed string.
@interface NSTextParagraph : NSTextElement

- (instancetype) initWithAttributedString: (NSAttributedString *) attributedString;

@property(readonly, strong) NSAttributedString *attributedString;
@property(readonly, strong, nullable) NSTextRange *paragraphContentRange;
@property(readonly, strong, nullable) NSTextRange *paragraphSeparatorRange;

@end

@class NSTextList;

// A text list node (macOS 12), declared as Apple's public documentation spells it: it inherits from NSTextParagraph
// and has the members below. The documentation does not say what -attributedString (the contents with the list
// marker and indentation) is, and this tree has no list marker layout, so that one raises instead of answering the
// contents without their marker; the ranges inherited from NSTextParagraph work on the contents.
@interface NSTextListElement : NSTextParagraph

- (instancetype) initWithParentElement: (nullable NSTextListElement *) parent
                              textList: (NSTextList *) textList
                              contents: (nullable NSAttributedString *) contents
                      markerAttributes: (nullable NSDictionary<NSString *, id> *) markerAttributes
                         childElements: (nullable NSArray<NSTextListElement *> *) children;

+ (instancetype) textListElementWithContents: (NSAttributedString *) contents
                            markerAttributes: (nullable NSDictionary<NSString *, id> *) markerAttributes
                                    textList: (NSTextList *) textList
                               childElements: (nullable NSArray<NSTextListElement *> *) children;
// The nesting level is documented as a parameter and nothing says what it does to an element made from children
// alone, so this one raises.
+ (nullable instancetype) textListElementWithChildElements: (NSArray<NSTextListElement *> *) children
                                                  textList: (NSTextList *) textList
                                              nestingLevel: (NSInteger) nestingLevel;

@property(readonly, strong) NSTextList *textList;
@property(readonly, strong, nullable) NSAttributedString *contents;
@property(readonly, strong, nullable) NSDictionary<NSString *, id> *markerAttributes;
@property(readonly, weak, nullable) NSTextListElement *parentElement;
@property(readonly, copy) NSArray<NSTextListElement *> *childElements;

@end
