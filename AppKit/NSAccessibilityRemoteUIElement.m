/*
 This file is part of Darling.

 Copyright (C) 2025 Darling Developers

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

#import <AppKit/NSAccessibilityRemoteUIElement.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

@implementation NSAccessibilityRemoteUIElement

/* darling-lol M57: these must return a real object. The previous
 * forwardInvocation fallback returned an uninitialized return buffer, so
 * Chromium's RemoteAccessibility got a garbage pointer from -initWithRemoteToken:
 * and crashed shortly after. */
- (id) init
{
    return [super init];
}

- (id) initWithRemoteToken: (id) token
{
    return [self init];
}

+ (id) remoteTokenForLocalUIElement: (id) element
{
    /* Chromium treats the return value as NSData and reads [data bytes] /
     * [data length]. Returning a non-NSData object made those land in
     * -forwardInvocation: (uninitialized return) -> a huge length ->
     * std::vector OOM. An empty NSData cleanly disables remote accessibility. */
    return [NSData data];
}

+ (void) setRemoteUIApp: (id) app
{
    /* Remote (cross-process) accessibility is not supported; accept and ignore. */
}

+ (void) registerRemoteUIProcessIdentifier: (int) pid
{
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
