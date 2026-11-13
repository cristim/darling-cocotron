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

// Documented at developer.apple.com/documentation/quartzcore/caedrmetadata
@interface CAEDRMetadata : NSObject <NSCopying, NSSecureCoding>

@property(class, retain, readonly) CAEDRMetadata *HLGMetadata;
@property(class, readonly, getter=isAvailable) BOOL available;

+ (CAEDRMetadata *) HDR10MetadataWithDisplayInfo: (NSData *) displayData
                                     contentInfo: (NSData *) contentData
                              opticalOutputScale: (float) scale;
+ (CAEDRMetadata *) HDR10MetadataWithMinLuminance: (float) minNits
                                     maxLuminance: (float) maxNits
                               opticalOutputScale: (float) scale;
+ (CAEDRMetadata *) HLGMetadataWithAmbientViewingEnvironment: (NSData *) data;

@end
