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

#import <AppKit/NSToolbarItem.h>
#import "NSStubForwarding-Private.h"

// Not in Apple's public headers; surveyed applications import the class, so
// it exists. Its superclass is a GUESS (rung 6), NSToolbarItem, because it is
// the only class an item in a toolbar can have.
@interface NSSeparatorToolbarItem : NSToolbarItem
@end

@implementation NSSeparatorToolbarItem
NS_STUB_FORWARDING
@end
