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

#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

// Not in Apple's public headers. Notes imports it by name (rung 5, demand
// analysis only), so the class exists to let the symbol bind. Its superclass
// is a GUESS (rung 6). It implements nothing; the first unimplemented message
// is logged and the rest are ignored.
@interface CTEmojiImageStrike : NSObject
@end

@implementation CTEmojiImageStrike

- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector {
    NSMethodSignature *signature = [super methodSignatureForSelector: selector];
    return signature != nil ? signature : [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void) forwardInvocation: (NSInvocation *) invocation {
    static BOOL logged;
    @synchronized([CTEmojiImageStrike class]) {
        if (logged)
            return;
        logged = YES;
    }
    NSLog(@"Stub called: %@ in %@ (further calls to this class are not logged)",
          NSStringFromSelector([invocation selector]), [self class]);
}

@end
