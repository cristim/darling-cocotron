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

#import <AppKit/NSTintConfiguration.h>
#import <AppKit/NSColor.h>

// Behaviour beyond what the documentation states is a GUESS (rung 6): the
// equivalent content tint is the base tint, and the coding keys are our own.
@implementation NSTintConfiguration {
    NSColor *_baseTintColor;
    BOOL _adaptsToUserAccentColor;
}

@synthesize baseTintColor = _baseTintColor;
@synthesize adaptsToUserAccentColor = _adaptsToUserAccentColor;

- (instancetype) initWithColor: (NSColor *) color adapts: (BOOL) adapts {
    if ((self = [super init]) != nil) {
        _baseTintColor = [color retain];
        _adaptsToUserAccentColor = adapts;
    }
    return self;
}

+ (NSTintConfiguration *) tintConfigurationWithPreferredColor: (NSColor *) color {
    return [[[self alloc] initWithColor: color adapts: YES] autorelease];
}

+ (NSTintConfiguration *) tintConfigurationWithFixedColor: (NSColor *) color {
    return [[[self alloc] initWithColor: color adapts: NO] autorelease];
}

+ (NSTintConfiguration *) defaultTintConfiguration {
    static NSTintConfiguration *shared;
    @synchronized(self) {
        if (shared == nil)
            shared = [[self alloc] initWithColor: nil adapts: NO];
    }
    return shared;
}

+ (NSTintConfiguration *) monochromeTintConfiguration {
    static NSTintConfiguration *shared;
    @synchronized(self) {
        if (shared == nil)
            shared = [[self alloc] initWithColor: nil adapts: NO];
    }
    return shared;
}

- (NSColor *) equivalentContentTintColor {
    return _baseTintColor;
}

- (void) dealloc {
    [_baseTintColor release];
    [super dealloc];
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    [coder encodeObject: _baseTintColor forKey: @"NSBaseTintColor"];
    [coder encodeBool: _adaptsToUserAccentColor forKey: @"NSAdaptsToUserAccentColor"];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    NSColor *color = [coder decodeObjectOfClass: [NSColor class] forKey: @"NSBaseTintColor"];
    return [self initWithColor: color adapts: [coder decodeBoolForKey: @"NSAdaptsToUserAccentColor"]];
}

@end
