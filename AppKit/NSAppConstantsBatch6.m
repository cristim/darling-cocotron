/*
 This file is part of Darling.

 Copyright (C) 2026 Darling developers

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

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>

// String constants that stock apps bind to AppKit (dyld collect-missing sweep, 69 apps: Mail, Notes, TV, Freeform, Photos,
// Reminders, VoiceOver Utility, Journal), plain data names with no behaviour behind them. Every string is the value a real Mac
// holds (macOS 26.1, mac-probe/darling_probe_a1.txt, rung 4); the type of the names not in the public documentation is a GUESS.
// Many carry their own name; the others (AXChildrenInNavigationOrder, AXPopover, AXEnhancedUserInterface, Credits, {hyphen},
// com.apple.UserFonts, NSToolbarWritingToolsItem, NSToolbarBookmarks, NSTextMovement, item) do not. Declared here, in no
// AppKit header.

APPKIT_EXPORT const NSNotificationName NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification;
APPKIT_EXPORT const NSNotificationName NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification;
APPKIT_EXPORT const NSNotificationName NSPopUpButtonCellWillPopUpNotification;
APPKIT_EXPORT const NSNotificationName NSMenuDidCompleteInteractionNotification;
APPKIT_EXPORT const NSNotificationName NSControlWillBeginContinuousTrackingNotification;
APPKIT_EXPORT const NSNotificationName NSControlDidEndContinuousTrackingNotification;
APPKIT_EXPORT const NSNotificationName NSWorkspaceAccessibilityFocusedElementDidChangeNotification;
APPKIT_EXPORT NSString *const NSAccessibilityChildrenInNavigationOrderAttribute;
APPKIT_EXPORT NSString *const NSAccessibilityFocusedElementKey;
APPKIT_EXPORT NSString *const NSAccessibilityPopoverRole;
APPKIT_EXPORT NSString *const NSAccessibilityEnhancedUserInterfaceAttribute;
APPKIT_EXPORT NSString *const NSToolbarWritingToolsItemIdentifier;
APPKIT_EXPORT NSString *const NSTouchBarItemIdentifierCandidateList;
APPKIT_EXPORT NSString *const NSTouchBarItemIdentifierTextAlignment;
APPKIT_EXPORT NSString *const NSTouchBarItemIdentifierTextColorPicker;
APPKIT_EXPORT NSString *const NSTouchBarItemIdentifierTextList;
APPKIT_EXPORT NSString *const NSTouchBarItemIdentifierTextStyle;
APPKIT_EXPORT NSString *const NSInspectorBarFontFamilyItemIdentifier;
APPKIT_EXPORT NSString *const NSInspectorBarFontSizeItemIdentifier;
APPKIT_EXPORT NSString *const NSInspectorBarFontStyleItemIdentifier;
APPKIT_EXPORT NSString *const NSInspectorBarSpaceItemIdentifier;
APPKIT_EXPORT NSString *const NSInspectorBarTextAlignmentItemIdentifier;
APPKIT_EXPORT NSString *const NSInspectorBarTextBackgroundColorItemIdentifier;
APPKIT_EXPORT NSString *const NSInspectorBarTextForegroundColorItemIdentifier;
APPKIT_EXPORT NSString *const NSInspectorBarTextListItemIdentifier;
APPKIT_EXPORT NSString *const NSAboutPanelOptionCredits;
APPKIT_EXPORT NSString *const NSTextListMarkerHyphen;
APPKIT_EXPORT NSString *const NSFontCollectionUser;
APPKIT_EXPORT NSString *const NSFullScreenModeAllScreens;
APPKIT_EXPORT NSString *const NSImageNameToolbarBookmarks;
APPKIT_EXPORT NSString *const NSTextMovementUserInfoKey;
APPKIT_EXPORT NSString *const NSToolbarItemKey;
APPKIT_EXPORT NSString *const NSOutlineViewShowHideButtonKey;

const NSNotificationName NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification = @"NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification";
const NSNotificationName NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification = @"NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification";
const NSNotificationName NSPopUpButtonCellWillPopUpNotification = @"NSPopUpButtonCellWillPopUpNotification";
const NSNotificationName NSMenuDidCompleteInteractionNotification = @"NSMenuDidCompleteInteractionNotification";
const NSNotificationName NSControlWillBeginContinuousTrackingNotification = @"NSControlWillBeginContinuousTrackingNotification";
const NSNotificationName NSControlDidEndContinuousTrackingNotification = @"NSControlDidEndContinuousTrackingNotification";
const NSNotificationName NSWorkspaceAccessibilityFocusedElementDidChangeNotification = @"NSWorkspaceAccessibilityFocusedElementDidChangeNotification";
NSString *const NSAccessibilityChildrenInNavigationOrderAttribute = @"AXChildrenInNavigationOrder";
NSString *const NSAccessibilityFocusedElementKey = @"NSAccessibilityFocusedElementKey";
NSString *const NSAccessibilityPopoverRole = @"AXPopover";
NSString *const NSAccessibilityEnhancedUserInterfaceAttribute = @"AXEnhancedUserInterface";
NSString *const NSToolbarWritingToolsItemIdentifier = @"NSToolbarWritingToolsItem";
NSString *const NSTouchBarItemIdentifierCandidateList = @"NSTouchBarItemIdentifierCandidateList";
NSString *const NSTouchBarItemIdentifierTextAlignment = @"NSTouchBarItemIdentifierTextAlignment";
NSString *const NSTouchBarItemIdentifierTextColorPicker = @"NSTouchBarItemIdentifierTextColorPicker";
NSString *const NSTouchBarItemIdentifierTextList = @"NSTouchBarItemIdentifierTextList";
NSString *const NSTouchBarItemIdentifierTextStyle = @"NSTouchBarItemIdentifierTextStyle";
NSString *const NSInspectorBarFontFamilyItemIdentifier = @"NSInspectorBarFontFamilyItemIdentifier";
NSString *const NSInspectorBarFontSizeItemIdentifier = @"NSInspectorBarFontSizeItemIdentifier";
NSString *const NSInspectorBarFontStyleItemIdentifier = @"NSInspectorBarFontStyleItemIdentifier";
NSString *const NSInspectorBarSpaceItemIdentifier = @"NSInspectorBarSpaceItemIdentifier";
NSString *const NSInspectorBarTextAlignmentItemIdentifier = @"NSInspectorBarTextAlignmentItemIdentifier";
NSString *const NSInspectorBarTextBackgroundColorItemIdentifier = @"NSInspectorBarTextBackgroundColorItemIdentifier";
NSString *const NSInspectorBarTextForegroundColorItemIdentifier = @"NSInspectorBarTextForegroundColorItemIdentifier";
NSString *const NSInspectorBarTextListItemIdentifier = @"NSInspectorBarTextListItemIdentifier";
NSString *const NSAboutPanelOptionCredits = @"Credits";
NSString *const NSTextListMarkerHyphen = @"{hyphen}";
NSString *const NSFontCollectionUser = @"com.apple.UserFonts";
NSString *const NSFullScreenModeAllScreens = @"NSFullScreenModeAllScreens";
NSString *const NSImageNameToolbarBookmarks = @"NSToolbarBookmarks";
NSString *const NSTextMovementUserInfoKey = @"NSTextMovement";
NSString *const NSToolbarItemKey = @"item";
NSString *const NSOutlineViewShowHideButtonKey = @"NSOutlineViewShowHideButtonKey";
