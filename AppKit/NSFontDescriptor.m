/* Copyright (c) 2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/NSDisplay.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontDescriptor.h>
#import <AppKit/NSRaise.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

NSFontDescriptorAttributeName NSFontFamilyAttribute = @"NSFontFamilyAttribute";
NSFontDescriptorAttributeName NSFontNameAttribute = @"NSFontNameAttribute";
NSFontDescriptorAttributeName NSFontFaceAttribute = @"NSFontFaceAttribute";
NSFontDescriptorAttributeName NSFontSizeAttribute = @"NSFontSizeAttribute";
NSFontDescriptorAttributeName NSFontVisibleNameAttribute = @"NSFontVisibleNameAttribute";
NSFontDescriptorAttributeName NSFontMatrixAttribute = @"NSFontMatrixAttribute";
NSFontDescriptorAttributeName NSFontVariationAttribute = @"NSCTFontVariationAttribute";
NSFontDescriptorAttributeName NSFontCharacterSetAttribute = @"NSCTFontCharacterSetAttribute";
NSFontDescriptorAttributeName NSFontCascadeListAttribute = @"NSCTFontCascadeListAttribute";
NSFontDescriptorAttributeName NSFontTraitsAttribute = @"NSCTFontTraitsAttribute";
NSFontDescriptorAttributeName NSFontFixedAdvanceAttribute = @"NSCTFontFixedAdvanceAttribute";
NSFontDescriptorAttributeName NSFontFeatureSettingsAttribute = @"NSCTFontFeatureSettingsAttribute";

NSFontDescriptorFeatureKey NSFontFeatureSelectorIdentifierKey = @"CTFeatureSelectorIdentifier";
NSFontDescriptorFeatureKey NSFontFeatureTypeIdentifierKey = @"CTFeatureTypeIdentifier";

NSFontDescriptorTraitKey NSFontSymbolicTrait = @"NSCTFontSymbolicTrait";
NSFontDescriptorTraitKey NSFontWeightTrait = @"NSCTFontWeightTrait";
NSFontDescriptorTraitKey NSFontWidthTrait = @"NSCTFontProportionTrait";
NSFontDescriptorTraitKey NSFontSlantTrait = @"NSCTFontSlantTrait";

// Valid range -1.0 to 1.0, 0.0 is regular (rung 3, NSFontDescriptor.TraitKey.weight).
// The numbers round the float32 values in tree since cdc08795, origin
// unrecorded (VibeDarling/darling#1498); kept as GUESS, NEEDS-REAL-MAC. The earlier
// initialisers were those bit patterns, which a CGFloat initialiser reads as
// the integer value (4.6e18 to 1.4e19).
const NSFontWeight NSFontWeightThin = -0.6;
const NSFontWeight NSFontWeightLight = -0.4;
const NSFontWeight NSFontWeightUltraLight = -0.8;
const NSFontWeight NSFontWeightBlack = 0.62;
const NSFontWeight NSFontWeightHeavy = 0.56;
const NSFontWeight NSFontWeightSemibold = 0.3;
const NSFontWeight NSFontWeightBold = 0.4;
const NSFontWeight NSFontWeightMedium = 0.23;
const NSFontWeight NSFontWeightRegular = 0.0;

NSFontDescriptorSystemDesign const NSFontDescriptorSystemDesignDefault = @"NSCTFontUIFontDesignDefault";
NSFontDescriptorSystemDesign const NSFontDescriptorSystemDesignSerif = @"NSCTFontUIFontDesignSerif";
NSFontDescriptorSystemDesign const NSFontDescriptorSystemDesignMonospaced = @"NSCTFontUIFontDesignMonospaced";
NSFontDescriptorSystemDesign const NSFontDescriptorSystemDesignRounded = @"NSCTFontUIFontDesignRounded";

NSFontTextStyle const NSFontTextStyleLargeTitle = @"NSFontTextStyleLargeTitle";
NSFontTextStyle const NSFontTextStyleTitle1 = @"NSFontTextStyleTitle1";
NSFontTextStyle const NSFontTextStyleTitle2 = @"NSFontTextStyleTitle2";
NSFontTextStyle const NSFontTextStyleTitle3 = @"NSFontTextStyleTitle3";
NSFontTextStyle const NSFontTextStyleHeadline = @"NSFontTextStyleHeadline";
NSFontTextStyle const NSFontTextStyleSubheadline = @"NSFontTextStyleSubheadline";
NSFontTextStyle const NSFontTextStyleBody = @"NSFontTextStyleBody";
NSFontTextStyle const NSFontTextStyleCallout = @"NSFontTextStyleCallout";
NSFontTextStyle const NSFontTextStyleFootnote = @"NSFontTextStyleFootnote";
NSFontTextStyle const NSFontTextStyleCaption1 = @"NSFontTextStyleCaption1";
NSFontTextStyle const NSFontTextStyleCaption2 = @"NSFontTextStyleCaption2";

static NSString *const NSFontUIFontDesignTrait = @"NSCTFontUIFontDesignTrait";

@implementation NSFontDescriptor : NSObject

- initWithFontAttributes: (NSDictionary *) attributes {
    _attributes = [attributes copy];
    return self;
}

- (void) dealloc {
    [_attributes release];
    [super dealloc];
}

- copyWithZone: (NSZone *) zone {
    return [self retain];
}

- (NSString *) description {
    return [NSString stringWithFormat: @"<%@ %@>", [self class], _attributes];
}

+ fontDescriptorWithFontAttributes: (NSDictionary *) attributes {
    return [[[self allocWithZone: NULL] initWithFontAttributes: attributes]
            autorelease];
}

+ fontDescriptorWithName: (NSString *) name
                  matrix: (NSAffineTransform *) matrix
{
    NSDictionary *attributes = [NSDictionary
            dictionaryWithObjectsAndKeys: name, NSFontNameAttribute, matrix,
                                          NSFontMatrixAttribute, nil];
    return [[[self allocWithZone: NULL] initWithFontAttributes: attributes]
            autorelease];
}

+ fontDescriptorWithName: (NSString *) name size: (CGFloat) pointSize {
    NSDictionary *attributes = [NSDictionary
            dictionaryWithObjectsAndKeys: name, NSFontNameAttribute,
                                          [[NSNumber numberWithFloat: pointSize]
                                                  stringValue],
                                          NSFontSizeAttribute, nil];

    return [[[self allocWithZone: NULL] initWithFontAttributes: attributes]
            autorelease];
}

- (NSDictionary *) fontAttributes {
    return _attributes;
}

- objectForKey: (NSString *) attributeKey {
    return [_attributes objectForKey: attributeKey];
}

- (CGFloat) pointSize {
    return [[_attributes objectForKey: NSFontSizeAttribute] floatValue];
}

- (NSAffineTransform *) matrix {
    return [_attributes objectForKey: NSFontMatrixAttribute];
}

- (NSFontSymbolicTraits) symbolicTraits {
    NSDictionary *fontTraits =
            [_attributes objectForKey: NSFontTraitsAttribute];
    return [[fontTraits objectForKey: NSFontSymbolicTrait] unsignedIntValue];
}

- (NSFontDescriptor *) fontDescriptorByAddingAttributes:
        (NSDictionary *) attributes
{
    NSMutableDictionary *copy =
            [NSMutableDictionary dictionaryWithDictionary: _attributes];

    [copy addEntriesFromDictionary: attributes];

    return [[self class] fontDescriptorWithFontAttributes: copy];
}

- (NSFontDescriptor *) fontDescriptorWithFace: (NSString *) face {
    NSMutableDictionary *copy =
            [NSMutableDictionary dictionaryWithDictionary: _attributes];

    [copy setObject: face forKey: NSFontFaceAttribute];

    return [[self class] fontDescriptorWithFontAttributes: copy];
}

- (NSFontDescriptor *) fontDescriptorWithFamily: (NSString *) family {
    NSMutableDictionary *copy =
            [NSMutableDictionary dictionaryWithDictionary: _attributes];

    [copy setObject: family forKey: NSFontFamilyAttribute];

    return [[self class] fontDescriptorWithFontAttributes: copy];
}

- (NSFontDescriptor *) fontDescriptorWithMatrix: (NSAffineTransform *) matrix {
    NSMutableDictionary *copy =
            [NSMutableDictionary dictionaryWithDictionary: _attributes];

    [copy setObject: matrix forKey: NSFontMatrixAttribute];

    return [[self class] fontDescriptorWithFontAttributes: copy];
}

- (NSFontDescriptor *) fontDescriptorWithSize: (CGFloat) pointSize {
    NSMutableDictionary *copy =
            [NSMutableDictionary dictionaryWithDictionary: _attributes];

    [copy setObject: [NSNumber numberWithFloat: pointSize]
             forKey: NSFontSizeAttribute];

    return [[self class] fontDescriptorWithFontAttributes: copy];
}

- (NSFontDescriptor *) fontDescriptorWithSymbolicTraits:
        (NSFontSymbolicTraits) traits
{
    NSMutableDictionary *copy =
            [NSMutableDictionary dictionaryWithDictionary: _attributes];

    NSMutableDictionary *traitsCopy = [NSMutableDictionary
            dictionaryWithDictionary:
                    [_attributes objectForKey: NSFontTraitsAttribute]];
    [traitsCopy setObject: [NSNumber numberWithUnsignedInt: traits]
                   forKey: NSFontSymbolicTrait];
    [copy setObject: traitsCopy forKey: NSFontTraitsAttribute];

    return [[self class] fontDescriptorWithFontAttributes: copy];
}

// Only system font descriptors and their design variants have designs;
// non-default designs map to fontconfig's CSS generic families.
- (NSFontDescriptor *) fontDescriptorWithDesign:
        (NSFontDescriptorSystemDesign) design
{
    NSString *systemFamily = [[NSFont systemFontOfSize: 0] familyName];
    if (systemFamily == nil) {
        return nil;
    }
    NSDictionary *traits = [_attributes objectForKey: NSFontTraitsAttribute];
    if ([traits objectForKey: NSFontUIFontDesignTrait] == nil) {
        NSFont *font = [NSFont fontWithDescriptor: self size: [self pointSize]];
        if (![[font familyName] isEqualToString: systemFamily]) {
            return nil;
        }
    }

    NSString *generic = nil;
    if ([design isEqualToString: NSFontDescriptorSystemDesignSerif]) {
        generic = @"serif";
    } else if ([design isEqualToString: NSFontDescriptorSystemDesignMonospaced]) {
        generic = @"monospace";
    } else if ([design isEqualToString: NSFontDescriptorSystemDesignRounded]) {
        generic = @"ui-rounded";
    } else if (![design isEqualToString: NSFontDescriptorSystemDesignDefault]) {
        return nil;
    }

    NSString *family = systemFamily;
    if (generic != nil) {
        family = [[NSDisplay currentDisplay] fontFamilyNameForGenericFamily: generic];
        if (family == nil) {
            return nil;
        }
    }

    NSMutableDictionary *attributes =
            [NSMutableDictionary dictionaryWithDictionary: _attributes];
    [attributes removeObjectsForKeys: @[
        NSFontNameAttribute, NSFontVisibleNameAttribute, NSFontFaceAttribute,
        NSFontFixedAdvanceAttribute
    ]];
    [attributes setObject: family forKey: NSFontFamilyAttribute];
    NSMutableDictionary *designTraits =
            [NSMutableDictionary dictionaryWithDictionary: traits];
    [designTraits setObject: design forKey: NSFontUIFontDesignTrait];
    [attributes setObject: designTraits forKey: NSFontTraitsAttribute];

    return [[self class] fontDescriptorWithFontAttributes: attributes];
}

- (NSArray *) matchingFontDescriptorsWithMandatoryKeys: (NSSet *) keys {
    NSUnimplementedMethod();
    return nil;
}

- (NSFontDescriptor *) matchingFontDescriptorWithMandatoryKeys: (NSSet *) keys {
    NSUnimplementedMethod();
    return nil;
}

@end
