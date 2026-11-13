/*
 This file is part of Darling.

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

#import <AppKit/NSUserInterfaceCompressionOptions.h>

// Specification: Apple's public documentation for NSUserInterfaceCompressionOptions
// (developer.apple.com/documentation/appkit/nsuserinterfacecompressionoptions), rung 3:
// an instance "contains zero or more options" and behaves like a set (union,
// subtraction, intersection, containment), is created empty or from an identifier
// string or from a set of options, and has four standard options plus their union.
// The Objective-C selector names (hideImagesOption, containsOptions:,
// optionsByAddingOptions:, initWithCompressionOptions:, and so on) are the
// Objective-C symbol identifiers in the page's data (its "occ" language variant).
//
// GUESS (rung 6), NEEDS-REAL-MAC: the standard option identifier strings and the
// NSCoding key. They do not reach any other API in this tree, so a different string
// would not change behaviour here.

static NSString *const kHideImages = @"NSUserInterfaceCompressionOptionHideImages";
static NSString *const kHideText = @"NSUserInterfaceCompressionOptionHideText";
static NSString *const kReduceMetrics = @"NSUserInterfaceCompressionOptionReduceMetrics";
static NSString *const kBreakEqualWidths = @"NSUserInterfaceCompressionOptionBreakEqualWidths";
static NSString *const kCodingKey = @"NSUserInterfaceCompressionOptionIdentifiers";

@implementation NSUserInterfaceCompressionOptions

+ (NSUserInterfaceCompressionOptions *) _optionWithIdentifier: (NSString *) identifier {
    return [[[self alloc] initWithIdentifier: identifier] autorelease];
}

+ (NSUserInterfaceCompressionOptions *) hideImagesOption {
    return [self _optionWithIdentifier: kHideImages];
}

+ (NSUserInterfaceCompressionOptions *) hideTextOption {
    return [self _optionWithIdentifier: kHideText];
}

+ (NSUserInterfaceCompressionOptions *) reduceMetricsOption {
    return [self _optionWithIdentifier: kReduceMetrics];
}

+ (NSUserInterfaceCompressionOptions *) breakEqualWidthsOption {
    return [self _optionWithIdentifier: kBreakEqualWidths];
}

+ (NSUserInterfaceCompressionOptions *) standardOptions {
    NSSet *all = [NSSet setWithObjects: kHideImages, kHideText, kReduceMetrics, kBreakEqualWidths, nil];
    return [[[self alloc] _initWithIdentifiers: all] autorelease];
}

- (instancetype) _initWithIdentifiers: (NSSet *) identifiers {
    if ((self = [super init]) != nil)
        _identifiers = [identifiers copy];
    return self;
}

- (instancetype) init {
    return [self _initWithIdentifiers: [NSSet set]];
}

- (instancetype) initWithIdentifier: (NSString *) identifier {
    return [self _initWithIdentifiers: [NSSet setWithObject: identifier]];
}

- (instancetype) initWithCompressionOptions: (NSSet *) options {
    NSMutableSet *union_ = [NSMutableSet set];
    for (NSUserInterfaceCompressionOptions *option in options)
        [union_ unionSet: option->_identifiers];
    return [self _initWithIdentifiers: union_];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    NSSet *identifiers = [coder decodeObjectForKey: kCodingKey];
    return [self _initWithIdentifiers: identifiers != nil ? identifiers : [NSSet set]];
}

- (void) encodeWithCoder: (NSCoder *) coder {
    [coder encodeObject: _identifiers forKey: kCodingKey];
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

- (void) dealloc {
    [_identifiers release];
    [super dealloc];
}

- (BOOL) isEmpty {
    return [_identifiers count] == 0;
}

- (BOOL) containsOptions: (NSUserInterfaceCompressionOptions *) options {
    return [options->_identifiers isSubsetOfSet: _identifiers];
}

- (BOOL) intersectsOptions: (NSUserInterfaceCompressionOptions *) options {
    return [_identifiers intersectsSet: options->_identifiers];
}

- (NSUserInterfaceCompressionOptions *) optionsByAddingOptions: (NSUserInterfaceCompressionOptions *) options {
    NSMutableSet *result = [[_identifiers mutableCopy] autorelease];
    [result unionSet: options->_identifiers];
    return [[[[self class] alloc] _initWithIdentifiers: result] autorelease];
}

- (NSUserInterfaceCompressionOptions *) optionsByRemovingOptions: (NSUserInterfaceCompressionOptions *) options {
    NSMutableSet *result = [[_identifiers mutableCopy] autorelease];
    [result minusSet: options->_identifiers];
    return [[[[self class] alloc] _initWithIdentifiers: result] autorelease];
}

- (BOOL) isEqual: (id) other {
    return [other isKindOfClass: [NSUserInterfaceCompressionOptions class]] &&
           [_identifiers isEqualToSet: ((NSUserInterfaceCompressionOptions *) other)->_identifiers];
}

- (NSUInteger) hash {
    return [_identifiers hash];
}

@end
