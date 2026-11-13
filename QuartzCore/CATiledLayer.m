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

#import <QuartzCore/CATiledLayer.h>

// Tiles are not requested or drawn; the layer keeps the documented properties
// and their documented defaults (1 level, bias 0, 256 by 256 tiles, 0.25
// second fade).
@implementation CATiledLayer

@synthesize levelsOfDetail = _levelsOfDetail;
@synthesize levelsOfDetailBias = _levelsOfDetailBias;
@synthesize tileSize = _tileSize;

+ (CFTimeInterval) fadeDuration {
    return 0.25;
}

- (instancetype) init {
    if ((self = [super init]) != nil) {
        _levelsOfDetail = 1;
        _tileSize = CGSizeMake(256.0, 256.0);
    }
    return self;
}

- (instancetype) initWithLayer: (id) layer {
    if ((self = [super initWithLayer: layer]) != nil) {
        if ([layer isKindOfClass: [CATiledLayer class]]) {
            CATiledLayer *other = layer;
            _levelsOfDetail = other->_levelsOfDetail;
            _levelsOfDetailBias = other->_levelsOfDetailBias;
            _tileSize = other->_tileSize;
        } else {
            _levelsOfDetail = 1;
            _tileSize = CGSizeMake(256.0, 256.0);
        }
    }
    return self;
}

@end
