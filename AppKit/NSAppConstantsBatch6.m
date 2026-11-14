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
// Reminders, VoiceOver Utility), one batch of plain data names with no behaviour behind them. Each carries its own name.
// Provenance by name: the two HDR notifications are a real-Mac observation (mac-probe darling_probe3.txt, value equals the
// symbol name); NSPopUpButtonCellWillPopUpNotification and NSFontCollectionUser follow the open-source GNUstep libs-gui
// (Source/externs.m). Every other value, and the type of the ones not in the public documentation, is GUESS (rung 6),
// NEEDS-REAL-MAC (mac-probe/darling_probe_a1.c). Declared here, in no AppKit header.

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

const NSNotificationName NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification = @"NSApplicationShouldBeginSuppressingHighDynamicRangeContentNotification";
const NSNotificationName NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification = @"NSApplicationShouldEndSuppressingHighDynamicRangeContentNotification";
const NSNotificationName NSPopUpButtonCellWillPopUpNotification = @"NSPopUpButtonCellWillPopUpNotification";
const NSNotificationName NSMenuDidCompleteInteractionNotification = @"NSMenuDidCompleteInteractionNotification";
const NSNotificationName NSControlWillBeginContinuousTrackingNotification = @"NSControlWillBeginContinuousTrackingNotification";
const NSNotificationName NSControlDidEndContinuousTrackingNotification = @"NSControlDidEndContinuousTrackingNotification";
const NSNotificationName NSWorkspaceAccessibilityFocusedElementDidChangeNotification = @"NSWorkspaceAccessibilityFocusedElementDidChangeNotification";
NSString *const NSAccessibilityChildrenInNavigationOrderAttribute = @"NSAccessibilityChildrenInNavigationOrderAttribute";
NSString *const NSAccessibilityFocusedElementKey = @"NSAccessibilityFocusedElementKey";
NSString *const NSAccessibilityPopoverRole = @"NSAccessibilityPopoverRole";
NSString *const NSAccessibilityEnhancedUserInterfaceAttribute = @"NSAccessibilityEnhancedUserInterfaceAttribute";
NSString *const NSToolbarWritingToolsItemIdentifier = @"NSToolbarWritingToolsItemIdentifier";
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
NSString *const NSAboutPanelOptionCredits = @"NSAboutPanelOptionCredits";
NSString *const NSTextListMarkerHyphen = @"NSTextListMarkerHyphen";
NSString *const NSFontCollectionUser = @"NSFontCollectionUser";
NSString *const NSFullScreenModeAllScreens = @"NSFullScreenModeAllScreens";
