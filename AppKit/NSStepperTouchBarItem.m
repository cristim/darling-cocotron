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

#import <AppKit/NSStepperTouchBarItem.h>

// Documented defaults: maxValue 59.0, minValue 0.0, increment 1.0 and an empty
// customization label. The value starts at 0, a GUESS (rung 6); the formatter
// and the drawing handler are kept but nothing draws on a Touch Bar.
@implementation NSStepperTouchBarItem {
    id _target;
    SEL _action;
    double _maxValue;
    double _minValue;
    double _increment;
    double _value;
    NSString *_customizationLabel;
    NSFormatter *_formatter;
    void (^_drawingHandler)(NSRect, double);
}

@synthesize target = _target;
@synthesize action = _action;
@synthesize maxValue = _maxValue;
@synthesize minValue = _minValue;
@synthesize increment = _increment;
@synthesize value = _value;

- (instancetype) initWithIdentifier: (NSTouchBarItemIdentifier) identifier {
    if ((self = [super initWithIdentifier: identifier]) != nil) {
        _maxValue = 59.0;
        _increment = 1.0;
        _customizationLabel = @"";
    }
    return self;
}

+ (instancetype) stepperTouchBarItemWithIdentifier: (NSTouchBarItemIdentifier) identifier
                                         formatter: (NSFormatter *) formatter {
    NSStepperTouchBarItem *item = [[[self alloc] initWithIdentifier: identifier] autorelease];
    item->_formatter = [formatter retain];
    return item;
}

+ (instancetype) stepperTouchBarItemWithIdentifier: (NSTouchBarItemIdentifier) identifier
                                    drawingHandler: (void (^)(NSRect, double)) drawingHandler {
    NSStepperTouchBarItem *item = [[[self alloc] initWithIdentifier: identifier] autorelease];
    item->_drawingHandler = [drawingHandler copy];
    return item;
}

- (NSString *) customizationLabel {
    return _customizationLabel;
}

- (void) setCustomizationLabel: (NSString *) label {
    [_customizationLabel autorelease];
    _customizationLabel = [(label != nil ? label : @"") copy];
}

- (void) dealloc {
    [_customizationLabel release];
    [_formatter release];
    [_drawingHandler release];
    [super dealloc];
}

@end
