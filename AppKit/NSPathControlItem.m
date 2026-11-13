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

#import <AppKit/NSPathControlItem.h>

// The documentation does not say how title and attributedTitle relate; they
// are stored independently and default to empty, a GUESS (rung 6). The item
// is created by NSPathControl, so URL stays nil until one sets it.
@implementation NSPathControlItem {
    NSAttributedString *_attributedTitle;
    NSImage *_image;
    NSString *_title;
    NSURL *_URL;
}

@synthesize attributedTitle = _attributedTitle;
@synthesize image = _image;
@synthesize title = _title;
@synthesize URL = _URL;

- (instancetype) init {
    if ((self = [super init]) != nil) {
        _title = @"";
        _attributedTitle = [[NSAttributedString alloc] initWithString: @""];
    }
    return self;
}

- (void) dealloc {
    [_attributedTitle release];
    [_image release];
    [_title release];
    [_URL release];
    [super dealloc];
}

@end
