/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

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

#import <AppKit/NSPreviewRepresentingActivityItem.h>

// The documentation lists the initializers only; the readonly properties are
// a GUESS (rung 6) so that a sharing service can read the item back.
// The item-provider initializer is not declared: nothing here loads providers.
@implementation NSPreviewRepresentingActivityItem
@synthesize item = _item;
@synthesize title = _title;
@synthesize image = _image;
@synthesize icon = _icon;

- (instancetype) initWithItem: (id) item
                        title: (NSString *) title
                        image: (NSImage *) image
                         icon: (NSImage *) icon {
    if ((self = [super init]) != nil) {
        _item = [item retain];
        _title = [title copy];
        _image = [image retain];
        _icon = [icon retain];
    }
    return self;
}

- (void) dealloc {
    [_item release];
    [_title release];
    [_image release];
    [_icon release];
    [super dealloc];
}

@end
