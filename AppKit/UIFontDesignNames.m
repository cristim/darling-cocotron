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

#import <AppKit/NSFontDescriptor.h>

// Names Books (a UIKit-for-Mac application) binds to AppKit. UIFontDescriptorSystemDesignDefault and Monospaced complete
// the four designs UIKit documents (Serif and Rounded are defined with the other UIFont names in darling-cocotron #529);
// the five UIFontSystemFontDesign names are not in the public documentation. Every value is GUESS (rung 6), NEEDS-REAL-MAC
// (mac-probe/darling_probe_a1.c): a name with an NSFontDescriptor counterpart carries its string, so a descriptor built
// with either name is read the same way; Compact and Condensed have none and follow the same spelling.
// Declared here, in no AppKit header.
APPKIT_EXPORT NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignDefault;
APPKIT_EXPORT NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignMonospaced;
APPKIT_EXPORT NSString *const UIFontSystemFontDesignCompact;
APPKIT_EXPORT NSString *const UIFontSystemFontDesignCondensed;
APPKIT_EXPORT NSString *const UIFontSystemFontDesignDefault;
APPKIT_EXPORT NSString *const UIFontSystemFontDesignRounded;
APPKIT_EXPORT NSString *const UIFontSystemFontDesignSerif;

NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignDefault = @"NSCTFontUIFontDesignDefault";
NSFontDescriptorSystemDesign const UIFontDescriptorSystemDesignMonospaced = @"NSCTFontUIFontDesignMonospaced";
NSString *const UIFontSystemFontDesignCompact = @"NSCTFontUIFontDesignCompact";
NSString *const UIFontSystemFontDesignCondensed = @"NSCTFontUIFontDesignCondensed";
NSString *const UIFontSystemFontDesignDefault = @"NSCTFontUIFontDesignDefault";
NSString *const UIFontSystemFontDesignRounded = @"NSCTFontUIFontDesignRounded";
NSString *const UIFontSystemFontDesignSerif = @"NSCTFontUIFontDesignSerif";
