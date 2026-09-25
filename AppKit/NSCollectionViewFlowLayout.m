/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <AppKit/NSCollectionViewFlowLayout.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSGeometry.h>
#import <Foundation/NSValue.h>

NSString *const NSCollectionElementKindSectionHeader =
        @"UICollectionElementKindSectionHeader";
NSString *const NSCollectionElementKindSectionFooter =
        @"UICollectionElementKindSectionFooter";

@implementation NSCollectionViewFlowLayout
@synthesize itemSize = _itemSize;

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

- (instancetype) init {
    if ((self = [super init]) != nil)
        _itemSize = NSMakeSize(50, 50);
    return self;
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    if ((self = [self init]) == nil)
        return nil;
    if ([coder allowsKeyedCoding] &&
        [coder containsValueForKey: @"NSItemSize"]) {
        id itemSize = [coder decodeObjectForKey: @"NSItemSize"];
        if ([itemSize isKindOfClass: [NSValue class]])
            _itemSize = [itemSize sizeValue];
        else if ([itemSize isKindOfClass: [NSString class]])
            _itemSize = NSSizeFromString(itemSize);
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    if ([coder allowsKeyedCoding])
        [coder encodeObject: [NSValue valueWithSize: _itemSize]
                    forKey: @"NSItemSize"];
}

@end
