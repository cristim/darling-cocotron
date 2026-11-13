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

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>

@class NSViewCornerRadius;

// Documented at developer.apple.com/documentation/appkit/nsviewcornerconfiguration
@interface NSViewCornerConfiguration : NSObject <NSCopying>

@property(class, copy, readonly) NSViewCornerConfiguration *capsuleCornerConfiguration;

+ (NSViewCornerConfiguration *) capsuleCornerConfigurationWithMaximumRadius: (CGFloat) maximumRadius;
+ (NSViewCornerConfiguration *) configurationWithRadius: (NSViewCornerRadius *) radius;
+ (NSViewCornerConfiguration *) configurationWithTopLeftRadius: (NSViewCornerRadius *) topLeftRadius
                                                topRightRadius: (NSViewCornerRadius *) topRightRadius
                                              bottomLeftRadius: (NSViewCornerRadius *) bottomLeftRadius
                                             bottomRightRadius: (NSViewCornerRadius *) bottomRightRadius;
+ (NSViewCornerConfiguration *) configurationWithUniformRadius: (NSViewCornerRadius *) radius;
+ (NSViewCornerConfiguration *) configurationWithUniformRadius: (NSViewCornerRadius *) radius
                                                topLeftRadius: (NSViewCornerRadius *) topLeftRadius
                                               topRightRadius: (NSViewCornerRadius *) topRightRadius
                                             bottomLeftRadius: (NSViewCornerRadius *) bottomLeftRadius
                                            bottomRightRadius: (NSViewCornerRadius *) bottomRightRadius;
+ (NSViewCornerConfiguration *) configurationWithUniformTopRadius: (NSViewCornerRadius *) topRadius
                                                    bottomRadius: (NSViewCornerRadius *) bottomRadius;
+ (NSViewCornerConfiguration *) configurationWithUniformLeftRadius: (NSViewCornerRadius *) leftRadius
                                                     rightRadius: (NSViewCornerRadius *) rightRadius;

@end
