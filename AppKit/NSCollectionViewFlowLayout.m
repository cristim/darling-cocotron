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
    // NSCollectionViewLayout does not implement initWithCoder:, so -initWithCoder: used to fall
    // through to -forwardInvocation: above and decode to nil. Any nib containing a flow layout then
    // failed in NSKeyedUnarchiver with "Failed to decode element N in array for key NS.objects",
    // which took the whole window down: Automator could not load its main window at all.
    // This class is still a stub, so decode to the same defaults -init uses rather than inventing a
    // key mapping; only the nil return was breaking nib loading.
    return [self init];
}

@end
