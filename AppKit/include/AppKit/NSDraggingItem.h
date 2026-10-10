/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <AppKit/AppKitExport.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

@protocol NSPasteboardWriting;

typedef NSString *NSDraggingImageComponentKey;

APPKIT_EXPORT NSDraggingImageComponentKey const NSDraggingImageComponentIconKey;
APPKIT_EXPORT NSDraggingImageComponentKey const NSDraggingImageComponentLabelKey;

@interface NSDraggingImageComponent : NSObject {
    NSDraggingImageComponentKey _key;
    id _contents;
    NSRect _frame;
}
+ (instancetype) draggingImageComponentWithKey: (NSDraggingImageComponentKey) key;
- (instancetype) initWithKey: (NSDraggingImageComponentKey) key;
@property(copy) NSDraggingImageComponentKey key;
// Only NSImage contents are used by the drag image builder.
@property(retain) id contents;
@property NSRect frame;
@end

@interface NSDraggingItem : NSObject {
    id _item;
    NSRect _draggingFrame;
    NSArray *(^_imageComponentsProvider)(void);
}
- (instancetype) initWithPasteboardWriter: (id<NSPasteboardWriting>) pasteboardWriter;
@property(readonly, retain) id item;
@property NSRect draggingFrame;
@property(copy) NSArray *(^imageComponentsProvider)(void);
@property(readonly, copy) NSArray *imageComponents;
- (void) setDraggingFrame: (NSRect) frame contents: (id) contents;
@end
