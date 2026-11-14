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

// A list item's element. The public documentation lists no members of its own.
// GUESS (not in the public documentation, not observed): the superclass is NSTextElement (it vends the element's
// range and content manager); Journal imports the class.
@interface NSTextListElement : NSTextElement
@end
