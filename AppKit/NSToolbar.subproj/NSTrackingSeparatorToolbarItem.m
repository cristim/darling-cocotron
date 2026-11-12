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

#import <AppKit/NSTrackingSeparatorToolbarItem.h>

// Stores the split view and divider it names; the toolbar does not yet align
// itself with that divider.
@implementation NSTrackingSeparatorToolbarItem
@synthesize splitView = _splitView;
@synthesize dividerIndex = _dividerIndex;

+ (instancetype) trackingSeparatorToolbarItemWithIdentifier: (NSToolbarItemIdentifier) identifier
                                                  splitView: (NSSplitView *) splitView
                                               dividerIndex: (NSInteger) dividerIndex {
    NSTrackingSeparatorToolbarItem *item =
            [[self alloc] initWithItemIdentifier: identifier];
    item->_splitView = splitView;
    item->_dividerIndex = dividerIndex;
    return [item autorelease];
}

@end
