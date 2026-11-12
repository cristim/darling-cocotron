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

#import <Foundation/Foundation.h>

// The documentation gives no case names or values here: both are a GUESS.
typedef NS_OPTIONS(NSUInteger, NSMediaLibrary) {
    NSMediaLibraryAudio = 1 << 0,
    NSMediaLibraryImage = 1 << 1,
    NSMediaLibraryMovie = 1 << 2,
};

@interface NSMediaLibraryBrowserController : NSObject {
    NSRect _frame;
    NSMediaLibrary _mediaLibraries;
}

+ (NSMediaLibraryBrowserController *) sharedMediaLibraryBrowserController;

@property NSRect frame;
@property NSMediaLibrary mediaLibraries;
@property(readonly, getter=isVisible) BOOL visible;

- (void) togglePanel: (id) sender;

@end
