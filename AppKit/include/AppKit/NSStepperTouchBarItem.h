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

#import <AppKit/NSTouchBarItem.h>

@class NSFormatter;

// Documented at developer.apple.com/documentation/appkit/nssteppertouchbaritem
@interface NSStepperTouchBarItem : NSTouchBarItem

+ (instancetype) stepperTouchBarItemWithIdentifier: (NSTouchBarItemIdentifier) identifier
                                         formatter: (NSFormatter *) formatter;
+ (instancetype) stepperTouchBarItemWithIdentifier: (NSTouchBarItemIdentifier) identifier
                                    drawingHandler: (void (^)(NSRect rect, double value)) drawingHandler;

@property(weak, nullable) id target;
@property(nullable) SEL action;
@property double maxValue;
@property double minValue;
@property double increment;
@property double value;
@property(copy, null_resettable) NSString *customizationLabel;

@end
