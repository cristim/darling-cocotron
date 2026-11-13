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

#import <AppKit/NSView.h>

@class NSColor;

// The constant names are documented at
// developer.apple.com/documentation/appkit/nsglasseffectview/style-swift.enum;
// the values are a GUESS (rung 6).
typedef NS_ENUM(NSInteger, NSGlassEffectViewStyle) {
    NSGlassEffectViewStyleRegular = 0,
    NSGlassEffectViewStyleClear = 1,
};

// Documented at developer.apple.com/documentation/appkit/nsglasseffectview
@interface NSGlassEffectView : NSView

@property(strong, nullable) NSView *contentView;
@property CGFloat cornerRadius;
@property(copy, nullable) NSColor *tintColor;
@property NSGlassEffectViewStyle style;
@property BOOL effectIsInteractive;

@end
