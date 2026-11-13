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

#import <AppKit/NSSharingService.h>
#import <AppKit/NSToolbarItem.h>

@protocol NSSharingServicePickerToolbarItemDelegate;

// Documented at developer.apple.com/documentation/appkit/nssharingservicepickertoolbaritem.
// The page also lists activityItemsConfiguration, a Mac Catalyst property of a
// UIKit type; it is not declared here.
@interface NSSharingServicePickerToolbarItem : NSToolbarItem

@property(weak, nullable) id<NSSharingServicePickerToolbarItemDelegate> delegate;

@end

// The page names the protocol and its parent but its members were not
// recorded, so it declares none (GUESS, rung 6).
@protocol NSSharingServicePickerToolbarItemDelegate <NSSharingServicePickerDelegate>
@end
