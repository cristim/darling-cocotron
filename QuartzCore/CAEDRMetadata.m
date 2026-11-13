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

#import <QuartzCore/CAEDRMetadata.h>

// Extended dynamic range output is not implemented: the factories return
// metadata objects that carry nothing, and available reports NO. The latter is
// a GUESS (rung 6) because the documentation gives no default.
@implementation CAEDRMetadata

+ (CAEDRMetadata *) HLGMetadata {
    return [[[self alloc] init] autorelease];
}

+ (BOOL) isAvailable {
    return NO;
}

+ (CAEDRMetadata *) HDR10MetadataWithDisplayInfo: (NSData *) displayData
                                     contentInfo: (NSData *) contentData
                              opticalOutputScale: (float) scale {
    return [[[self alloc] init] autorelease];
}

+ (CAEDRMetadata *) HDR10MetadataWithMinLuminance: (float) minNits
                                     maxLuminance: (float) maxNits
                               opticalOutputScale: (float) scale {
    return [[[self alloc] init] autorelease];
}

+ (CAEDRMetadata *) HLGMetadataWithAmbientViewingEnvironment: (NSData *) data {
    return [[[self alloc] init] autorelease];
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder: (NSCoder *) coder {
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    return [self init];
}

@end
