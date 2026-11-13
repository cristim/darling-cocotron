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

#import <AppKit/NSSharingServicePickerToolbarItem.h>
#import "NSStubForwarding-Private.h"

// Presenting the share picker is not implemented: the item stores its
// delegate and every other unimplemented message is logged once and ignored.
@implementation NSSharingServicePickerToolbarItem {
    id<NSSharingServicePickerToolbarItemDelegate> _delegate;
}

NS_STUB_FORWARDING

@synthesize delegate = _delegate;

@end
