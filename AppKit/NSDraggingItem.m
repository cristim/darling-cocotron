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

#import <Foundation/Foundation.h>
#import <AppKit/NSDraggingItem.h>

NSDraggingImageComponentKey const NSDraggingImageComponentIconKey = @"icon";
NSDraggingImageComponentKey const NSDraggingImageComponentLabelKey = @"label";

@implementation NSDraggingImageComponent

@synthesize key = _key, contents = _contents, frame = _frame;

+ (instancetype)draggingImageComponentWithKey:(NSDraggingImageComponentKey)key
{
    return [[[self alloc] initWithKey:key] autorelease];
}

- (instancetype)initWithKey:(NSDraggingImageComponentKey)key
{
    if ((self = [super init]))
        _key = [key copy];
    return self;
}

- (void)dealloc
{
    [_key release];
    [_contents release];
    [super dealloc];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end

@implementation NSDraggingItem

@synthesize item = _item, draggingFrame = _draggingFrame;

- (instancetype)initWithPasteboardWriter:(id<NSPasteboardWriting>)pasteboardWriter
{
    if (pasteboardWriter == nil)
    {
        NSLog(@"NSDraggingItem: initWithPasteboardWriter: nil writer, returning nil");
        [self release];
        return nil;
    }
    if ((self = [super init]))
        _item = [pasteboardWriter retain];
    return self;
}

- (void)dealloc
{
    [_item release];
    [_imageComponentsProvider release];
    [super dealloc];
}

- (NSArray *(^)(void))imageComponentsProvider
{
    return _imageComponentsProvider;
}

- (void)setImageComponentsProvider:(NSArray *(^)(void))provider
{
    if (provider != _imageComponentsProvider)
    {
        [_imageComponentsProvider release];
        _imageComponentsProvider = [provider copy];
    }
}

- (NSArray *)imageComponents
{
    return _imageComponentsProvider != nil ? _imageComponentsProvider() : nil;
}

- (void)setDraggingFrame:(NSRect)frame contents:(id)contents
{
    NSDraggingImageComponent *icon = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];

    _draggingFrame = frame;
    icon.contents = contents;
    icon.frame = NSMakeRect(0, 0, frame.size.width, frame.size.height);
    [self setImageComponentsProvider:^NSArray *{ return @[ icon ]; }];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
