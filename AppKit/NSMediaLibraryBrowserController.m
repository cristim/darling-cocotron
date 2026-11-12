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

#import <AppKit/NSMediaLibraryBrowserController.h>
#import "NSStubForwarding-Private.h"

// There is no media browser panel: it is never visible, and toggling it is
// logged once.
@implementation NSMediaLibraryBrowserController
@synthesize frame = _frame;
@synthesize mediaLibraries = _mediaLibraries;

+ (NSMediaLibraryBrowserController *) sharedMediaLibraryBrowserController {
    static NSMediaLibraryBrowserController *shared;
    @synchronized(self) {
        if (shared == nil)
            shared = [[self alloc] init];
    }
    return shared;
}

- (BOOL) isVisible {
    return NO;
}

- (void) togglePanel: (id) sender {
    NSStubLogUnimplementedOnce([self class], _cmd);
}

@end
