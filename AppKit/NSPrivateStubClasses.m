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
#import "NSStubForwarding-Private.h"

// Classes that are not in Apple's public headers and that stock applications
// import by name. The names come from demand analysis only (rung 5) and every
// superclass is a GUESS (rung 6), NSObject unless the name says otherwise.
// They exist so that the symbols bind; none implements anything, and the
// first unimplemented message to each is logged.

@interface NSGlassView : NSView
@end
@implementation NSGlassView
NS_STUB_FORWARDING
@end

@interface NSPreferences : NSObject
@end
@implementation NSPreferences
NS_STUB_FORWARDING
@end

@interface NSTextEncapsulation : NSObject
@end
@implementation NSTextEncapsulation
NS_STUB_FORWARDING
@end

@interface NSEmojiImageAsset : NSObject
@end
@implementation NSEmojiImageAsset
NS_STUB_FORWARDING
@end

@interface NSEmojiImageStrike : NSObject
@end
@implementation NSEmojiImageStrike
NS_STUB_FORWARDING
@end

@interface _NSCloudSharingParticipantDetails : NSObject
@end
@implementation _NSCloudSharingParticipantDetails
NS_STUB_FORWARDING
@end
