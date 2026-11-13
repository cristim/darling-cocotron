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

#import <AppKit/NSButtonTouchBarItem.h>

// The button is not drawn on a Touch Bar; the item stores its documented
// properties. Defaults the documentation omits are a GUESS (rung 6): enabled
// is YES and the title is empty. The customization label defaults to the
// empty string, as the sibling stepper item documents.
@implementation NSButtonTouchBarItem {
    NSString *_title;
    NSImage *_image;
    NSColor *_bezelColor;
    BOOL _enabled;
    id _target;
    SEL _action;
    NSString *_customizationLabel;
}

@synthesize title = _title;
@synthesize image = _image;
@synthesize bezelColor = _bezelColor;
@synthesize enabled = _enabled;
@synthesize target = _target;
@synthesize action = _action;

- (instancetype) initWithIdentifier: (NSTouchBarItemIdentifier) identifier {
    if ((self = [super initWithIdentifier: identifier]) != nil) {
        _title = @"";
        _enabled = YES;
        _customizationLabel = @"";
    }
    return self;
}

+ (instancetype) buttonTouchBarItemWithIdentifier: (NSTouchBarItemIdentifier) identifier
                                            title: (NSString *) title
                                            image: (NSImage *) image
                                           target: (id) target
                                           action: (SEL) action {
    NSButtonTouchBarItem *item = [[[self alloc] initWithIdentifier: identifier] autorelease];
    if (title != nil)
        item.title = title;
    item.image = image;
    item.target = target;
    item.action = action;
    return item;
}

+ (instancetype) buttonTouchBarItemWithIdentifier: (NSTouchBarItemIdentifier) identifier
                                            title: (NSString *) title
                                           target: (id) target
                                           action: (SEL) action {
    return [self buttonTouchBarItemWithIdentifier: identifier title: title image: nil target: target action: action];
}

+ (instancetype) buttonTouchBarItemWithIdentifier: (NSTouchBarItemIdentifier) identifier
                                            image: (NSImage *) image
                                           target: (id) target
                                           action: (SEL) action {
    return [self buttonTouchBarItemWithIdentifier: identifier title: nil image: image target: target action: action];
}

- (NSString *) customizationLabel {
    return _customizationLabel;
}

- (void) setCustomizationLabel: (NSString *) label {
    [_customizationLabel autorelease];
    _customizationLabel = [(label != nil ? label : @"") copy];
}

- (void) dealloc {
    [_title release];
    [_image release];
    [_bezelColor release];
    [_customizationLabel release];
    [super dealloc];
}

@end
