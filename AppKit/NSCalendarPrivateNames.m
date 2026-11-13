/*
 This file is part of Darling.

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


#import <AppKit/NSAccessibilityConstants.h>
#import <AppKit/NSView.h>
#include <dispatch/dispatch.h>

@interface NSBannerView : NSView
@end
@interface NSPopoverFrame : NSView
@end
@interface NSPopoverAnimationController : NSObject
@end
@interface NSToolbarItemBadge : NSObject
@end

// Names Calendar imports from AppKit that have no public documentation. The
// guest application's imports supply each NAME only (rung 5); everything below is
// GUESS (rung 6), NEEDS-REAL-MAC.

// String values equal the constant's own name, as NSAccessibilityPressAction and
// its neighbours do in this tree.
NSString *const NSAccessibilityDateTimeComponentsAttribute = @"NSAccessibilityDateTimeComponentsAttribute";
NSString *const NSAccessibilityOpenAction = @"NSAccessibilityOpenAction";
NSString *const NSSharingServiceParametersDefaultRecipientsKey = @"NSSharingServiceParametersDefaultRecipientsKey";

// Whether this is a function, what it takes and what it returns are all unknown;
// the name suggests a function of an NSTableViewRowSizeStyle. A caller that expects
// a struct would read an unset result, so the call is logged once.
NSInteger NSSidebarMetricsForRowSize(NSInteger rowSizeStyle) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"NSSidebarMetricsForRowSize: not implemented, returning 0");
    });
    return 0;
}

// Unimplemented instance messages are logged and ignored, as in NSATSTypesetter.
#define CALENDAR_STUB_FORWARDING                                                      \
    - (NSMethodSignature *) methodSignatureForSelector: (SEL) selector {              \
        NSMethodSignature *signature = [super methodSignatureForSelector: selector];  \
        return signature != nil ? signature : [NSMethodSignature signatureWithObjCTypes: "v@:"]; \
    }                                                                                 \
    - (void) forwardInvocation: (NSInvocation *) invocation {                         \
        NSLog(@"Stub called: %@ in %@", NSStringFromSelector([invocation selector]), [self class]); \
    }

@implementation NSBannerView
CALENDAR_STUB_FORWARDING
@end

@implementation NSPopoverFrame
CALENDAR_STUB_FORWARDING
@end

@implementation NSPopoverAnimationController
CALENDAR_STUB_FORWARDING
@end

@implementation NSToolbarItemBadge
CALENDAR_STUB_FORWARDING
@end
