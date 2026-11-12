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

#import <Foundation/Foundation.h>

// For classes that exist so applications can bind them and that implement
// none of their API yet. Put NS_STUB_FORWARDING inside the @implementation:
// the first unimplemented message a class receives is logged, the rest are
// ignored, and every implemented method keeps its real signature.
void NSStubLogUnimplementedOnce(Class cls, SEL selector);

#define NS_STUB_FORWARDING                                                      \
    -(NSMethodSignature *) methodSignatureForSelector : (SEL) selector {        \
        NSMethodSignature *signature = [super methodSignatureForSelector: selector]; \
        return signature != nil ? signature                                     \
                                : [NSMethodSignature signatureWithObjCTypes: "v@:"]; \
    }                                                                           \
    -(void) forwardInvocation : (NSInvocation *) invocation {                   \
        NSStubLogUnimplementedOnce([self class], [invocation selector]);        \
    }
