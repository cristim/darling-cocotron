#import "NSAttributeRun.h"

@implementation _NSAttributes
- (id) initWithAttributes: (NSDictionary *) attributes range: (NSRange) range {
    if ((self = [super init])) {
        _range = range;
        _attributes = [attributes copy];
    }
    return self;
}

- (void) dealloc {
    [_attributes release];

    [super dealloc];
}

- (void) setAttributesInTextStorage: (NSTextStorage *) textStorage {
    [textStorage setAttributes: _attributes range: _range];
}

@end

@implementation _NSAttributeRun
- (id) initWithTextStorage: (NSTextStorage *) textStorage
                     range: (NSRange) range
{
    if ((self = [super init])) {
        _range = range;
        _textStorage = [_textStorage retain];

        _attributesArray = [[NSMutableArray alloc] init];
        int location = range.location;
        do {
            NSRange effectiveRange;
            NSDictionary *attrs =
                    [textStorage attributesAtIndex: location
                                    effectiveRange: &effectiveRange];
            NSRange attrRange = NSIntersectionRange(range, effectiveRange);
            _NSAttributes *attributes = [[[_NSAttributes alloc]
                    initWithAttributes: attrs
                                 range: attrRange] autorelease];
            [_attributesArray addObject: attributes];

            location = NSMaxRange(effectiveRange);
        } while (location < NSMaxRange(range));
    }
    return self;
}

- (void) dealloc {
    [_textStorage release];
    [_attributesArray release];

    [super dealloc];
}

- (void) restoreAttributesOfTextStorage: (NSTextStorage *) textStorage {
    [textStorage beginEditing];
    for (_NSAttributes *attr in _attributesArray) {
        [attr setAttributesInTextStorage: textStorage];
    }
    [textStorage endEditing];
}

- (id) copyWithZone: (NSZone *) zone {
    _NSAttributeRun *run = [[[self class] allocWithZone: zone] init];
    run->_range = _range;
    run->_attributesArray = [_attributesArray copyWithZone: zone];
    run->_textStorage = [_textStorage retain];
    return run;
}

- (NSRange) range {
    return _range;
}
@end
