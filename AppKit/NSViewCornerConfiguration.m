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

#import <AppKit/NSViewCornerConfiguration.h>
#import "NSStubForwarding-Private.h"

// The documentation lists the factories but not how a configuration resolves
// its radii, so every factory returns an empty instance that logs the first
// unimplemented message; the arguments are not kept. A GUESS (rung 6).
@implementation NSViewCornerConfiguration

NS_STUB_FORWARDING

+ (NSViewCornerConfiguration *) capsuleCornerConfiguration {
    return [[[self alloc] init] autorelease];
}

+ (NSViewCornerConfiguration *) capsuleCornerConfigurationWithMaximumRadius: (CGFloat) maximumRadius {
    return [[[self alloc] init] autorelease];
}

+ (NSViewCornerConfiguration *) configurationWithRadius: (NSViewCornerRadius *) radius {
    return [[[self alloc] init] autorelease];
}

+ (NSViewCornerConfiguration *) configurationWithTopLeftRadius: (NSViewCornerRadius *) topLeftRadius
                                                topRightRadius: (NSViewCornerRadius *) topRightRadius
                                              bottomLeftRadius: (NSViewCornerRadius *) bottomLeftRadius
                                             bottomRightRadius: (NSViewCornerRadius *) bottomRightRadius {
    return [[[self alloc] init] autorelease];
}

+ (NSViewCornerConfiguration *) configurationWithUniformRadius: (NSViewCornerRadius *) radius {
    return [[[self alloc] init] autorelease];
}

+ (NSViewCornerConfiguration *) configurationWithUniformRadius: (NSViewCornerRadius *) radius
                                                topLeftRadius: (NSViewCornerRadius *) topLeftRadius
                                               topRightRadius: (NSViewCornerRadius *) topRightRadius
                                             bottomLeftRadius: (NSViewCornerRadius *) bottomLeftRadius
                                            bottomRightRadius: (NSViewCornerRadius *) bottomRightRadius {
    return [[[self alloc] init] autorelease];
}

+ (NSViewCornerConfiguration *) configurationWithUniformTopRadius: (NSViewCornerRadius *) topRadius
                                                    bottomRadius: (NSViewCornerRadius *) bottomRadius {
    return [[[self alloc] init] autorelease];
}

+ (NSViewCornerConfiguration *) configurationWithUniformLeftRadius: (NSViewCornerRadius *) leftRadius
                                                     rightRadius: (NSViewCornerRadius *) rightRadius {
    return [[[self alloc] init] autorelease];
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

@end
