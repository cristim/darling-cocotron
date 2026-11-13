#import <CoreText/CTFontCollection.h>
#import <CoreText/CTFontDescriptor.h>
#import <Foundation/Foundation.h>
#import "KTCoreTextInternal.h"
#include <stdio.h>

static NSDictionary *attributesOf(id descriptor) {
    return (NSDictionary *)KTCoreTextDescriptorAttributes((CTFontDescriptorRef)descriptor);
}

const CFStringRef kCTFontCollectionRemoveDuplicatesOption = CFSTR("CTFontCollectionRemoveDuplicatesOption");
const CFStringRef kCTFontCollectionIncludeDisabledFontsOption = CFSTR("CTFontCollectionIncludeDisabledFontsOption");
const CFStringRef kCTFontCollectionDisallowAutoActivationOption = CFSTR("CTFontCollectionDisallowAutoActivationOption");

static NSArray *defaultAvailableFontDescriptors(void) {
    static NSArray *s_defaultDescriptors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const char * const fontNames[] = {
            "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique",
            "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic",
            "Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique",
            "ArialMT", "Arial-BoldMT", "Arial-ItalicMT", "Arial-BoldItalicMT",
            "Menlo-Regular", "Menlo-Bold", "Menlo-Italic", "Menlo-BoldItalic",
            "Monaco", "Geneva", "Symbol", "Apple Color Emoji",
            "DejaVu Sans", "DejaVu Sans Bold", "DejaVu Sans Oblique", "DejaVu Sans Bold Oblique",
            "DejaVu Serif", "DejaVu Serif Bold", "DejaVu Serif Italic", "DejaVu Serif Bold Italic",
            "DejaVu Sans Mono", "DejaVu Sans Mono Bold", "DejaVu Sans Mono Oblique", "DejaVu Sans Mono Bold Oblique",
            "Liberation Sans", "Liberation Serif", "Liberation Mono",
            "Roboto", "San Francisco"
        };
        static const char * const fontFamilies[] = {
            "Helvetica", "Helvetica", "Helvetica", "Helvetica",
            "Times", "Times", "Times", "Times",
            "Courier", "Courier", "Courier", "Courier",
            "Arial", "Arial", "Arial", "Arial",
            "Menlo", "Menlo", "Menlo", "Menlo",
            "Monaco", "Geneva", "Symbol", "Apple Color Emoji",
            "DejaVu Sans", "DejaVu Sans", "DejaVu Sans", "DejaVu Sans",
            "DejaVu Serif", "DejaVu Serif", "DejaVu Serif", "DejaVu Serif",
            "DejaVu Sans Mono", "DejaVu Sans Mono", "DejaVu Sans Mono", "DejaVu Sans Mono",
            "Liberation Sans", "Liberation Serif", "Liberation Mono",
            "Roboto", "San Francisco"
        };
        NSMutableArray *list = [NSMutableArray array];
        size_t count = sizeof(fontNames) / sizeof(fontNames[0]);
        for (size_t i = 0; i < count; i++) {
            NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
            NSString *postscript = [NSString stringWithUTF8String:fontNames[i]];
            NSString *family = [NSString stringWithUTF8String:fontFamilies[i]];
            attrs[(id)kCTFontNameAttribute] = postscript;
            attrs[(id)kCTFontFamilyNameAttribute] = family;
            attrs[(id)kCTFontDisplayNameAttribute] = postscript;
            attrs[(id)kCTFontPostScriptNameAttribute] = postscript;
            attrs[(id)kCTFontSizeAttribute] = [NSNumber numberWithDouble:12.0];
            CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attrs);
            [list addObject:(id)descriptor];
            CFRelease(descriptor);
        }
        s_defaultDescriptors = [list copy];
    });
    return s_defaultDescriptors;
}

@interface _CTFontCollection : NSObject <NSCopying, NSMutableCopying> {
@public
    NSMutableArray *_queryDescriptors;
    NSMutableArray *_exclusionDescriptors;
    NSDictionary *_options;
}
- (instancetype)initWithDescriptors:(NSArray *)descriptors options:(NSDictionary *)options;
- (NSArray *)matchingFontDescriptorsWithOptions:(NSDictionary *)options;
@end

@implementation _CTFontCollection

- (instancetype)initWithDescriptors:(NSArray *)descriptors options:(NSDictionary *)options {
    self = [super init];
    if (self) {
        _queryDescriptors = descriptors ? [descriptors mutableCopy] : [[NSMutableArray alloc] init];
        _exclusionDescriptors = [[NSMutableArray alloc] init];
        _options = options ? [options copy] : nil;
    }
    return self;
}

- (void)dealloc {
    [_queryDescriptors release];
    [_exclusionDescriptors release];
    [_options release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
    _CTFontCollection *copy = [[_CTFontCollection allocWithZone:zone] initWithDescriptors:_queryDescriptors options:_options];
    [copy->_exclusionDescriptors addObjectsFromArray:_exclusionDescriptors];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return [self copyWithZone:zone];
}

- (NSArray *)matchingFontDescriptorsWithOptions:(NSDictionary *)options {
    NSArray *source = (_queryDescriptors.count > 0) ? _queryDescriptors : defaultAvailableFontDescriptors();
    BOOL removeDuplicates = NO;

    id opt = [_options objectForKey:(id)kCTFontCollectionRemoveDuplicatesOption];
    if (!opt && options) {
        opt = [options objectForKey:(id)kCTFontCollectionRemoveDuplicatesOption];
    }
    if (opt && [opt respondsToSelector:@selector(boolValue)]) {
        removeDuplicates = [opt boolValue];
    }

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:source.count];
    NSMutableSet *seenNames = removeDuplicates ? [NSMutableSet set] : nil;

    for (id item in source) {
        // Check exclusions:
        // TODO: Full CoreText fuzzy attribute matching. For now, match against all attributes present in exclusion descriptor.
        BOOL excluded = NO;
        if (_exclusionDescriptors.count > 0) {
            NSDictionary *itemDict = attributesOf(item);
            for (id excl in _exclusionDescriptors) {
                NSDictionary *exclDict = attributesOf(excl);
                if (exclDict.count == 0) continue;
                BOOL allMatched = YES;
                for (id key in exclDict) {
                    id expected = exclDict[key];
                    id actual = itemDict[key];
                    if (!actual || ![actual isEqual:expected]) {
                        allMatched = NO;
                        break;
                    }
                }
                if (allMatched) {
                    excluded = YES;
                    break;
                }
            }
        }
        if (excluded) continue;

        NSDictionary *itemAttributes = attributesOf(item);
        NSString *name = [itemAttributes objectForKey:(id)kCTFontNameAttribute]
            ?: [itemAttributes objectForKey:(id)kCTFontPostScriptNameAttribute]
            ?: [itemAttributes objectForKey:(id)kCTFontFamilyNameAttribute];

        if (seenNames && name) {
            if ([seenNames containsObject:name]) continue;
            [seenNames addObject:name];
        }

        [result addObject:item];
    }

    return result;
}

@end

CFTypeID CTFontCollectionGetTypeID(void)
{
    return (CFTypeID)[_CTFontCollection self];
}

CTFontCollectionRef CTFontCollectionCreateFromAvailableFonts(CFDictionaryRef options)
{
    return (CTFontCollectionRef)[[_CTFontCollection alloc] initWithDescriptors:nil options:(NSDictionary *)options];
}

CTFontCollectionRef CTFontCollectionCreateWithFontDescriptors(CFArrayRef queryDescriptors, CFDictionaryRef options)
{
    return (CTFontCollectionRef)[[_CTFontCollection alloc] initWithDescriptors:(NSArray *)queryDescriptors options:(NSDictionary *)options];
}

CTFontCollectionRef CTFontCollectionCreateCopyWithFontDescriptors(CTFontCollectionRef collection, CFArrayRef queryDescriptors, CFDictionaryRef options)
{
    if (!collection) return NULL;
    _CTFontCollection *col = (_CTFontCollection *)collection;
    NSArray *descs = queryDescriptors ? (NSArray *)queryDescriptors : (NSArray *)col->_queryDescriptors;
    NSDictionary *opts = options ? (NSDictionary *)options : col->_options;
    _CTFontCollection *copy = [[_CTFontCollection alloc] initWithDescriptors:descs options:opts];
    [copy->_exclusionDescriptors addObjectsFromArray:col->_exclusionDescriptors];
    return (CTFontCollectionRef)copy;
}

CTMutableFontCollectionRef CTFontCollectionCreateMutableCopy(CTFontCollectionRef collection)
{
    if (!collection) return NULL;
    _CTFontCollection *col = (_CTFontCollection *)collection;
    _CTFontCollection *copy = [[_CTFontCollection alloc] initWithDescriptors:col->_queryDescriptors options:col->_options];
    [copy->_exclusionDescriptors addObjectsFromArray:col->_exclusionDescriptors];
    return (CTMutableFontCollectionRef)copy;
}

CFArrayRef CTFontCollectionCreateMatchingFontDescriptors(CTFontCollectionRef collection)
{
    return CTFontCollectionCreateMatchingFontDescriptorsWithOptions(collection, NULL);
}

CFArrayRef CTFontCollectionCreateMatchingFontDescriptorsWithOptions(CTFontCollectionRef collection, CFDictionaryRef options)
{
    if (!collection) return NULL;
    _CTFontCollection *col = (_CTFontCollection *)collection;
    NSArray *matched = [col matchingFontDescriptorsWithOptions:(NSDictionary *)options];
    return (CFArrayRef)[matched copy];
}

CFArrayRef CTFontCollectionCreateMatchingFontDescriptorsSortedWithCallback(
    CTFontCollectionRef collection,
    CTFontCollectionSortDescriptorsCallback sortCallback,
    void *refCon)
{
    if (!collection) return NULL;
    CFArrayRef tmp = CTFontCollectionCreateMatchingFontDescriptors(collection);
    if (!tmp) return NULL;
    NSArray *descriptors = (NSArray *)tmp;
    if (!sortCallback) {
        CFArrayRef result = (CFArrayRef)[descriptors copy];
        CFRelease(tmp);
        return result;
    }
    NSArray *sorted = [descriptors sortedArrayUsingFunction:(NSInteger (*)(id, id, void *))sortCallback context:refCon];
    CFArrayRef result = (CFArrayRef)[sorted copy];
    CFRelease(tmp);
    return result;
}

CFArrayRef CTFontCollectionCreateMatchingFontDescriptorsForFamily(
    CTFontCollectionRef collection,
    CFStringRef familyName,
    CFDictionaryRef options)
{
    if (!collection || !familyName) return NULL;
    CFArrayRef tmp = CTFontCollectionCreateMatchingFontDescriptorsWithOptions(collection, options);
    if (!tmp) return NULL;
    NSArray *descriptors = (NSArray *)tmp;
    NSMutableArray *filtered = [NSMutableArray array];
    for (id desc in descriptors) {
        NSString *fam = [attributesOf(desc) objectForKey:(id)kCTFontFamilyNameAttribute];
        if ([fam isEqualToString:(NSString *)familyName]) {
            [filtered addObject:desc];
        }
    }
    CFArrayRef result = (CFArrayRef)[filtered copy];
    CFRelease(tmp);
    return result;
}

CFArrayRef CTFontCollectionCopyQueryDescriptors(CTFontCollectionRef collection)
{
    if (!collection) return NULL;
    _CTFontCollection *col = (_CTFontCollection *)collection;
    return (CFArrayRef)[col->_queryDescriptors copy];
}

CFArrayRef CTFontCollectionCopyExclusionDescriptors(CTFontCollectionRef collection)
{
    if (!collection) return NULL;
    _CTFontCollection *col = (_CTFontCollection *)collection;
    return (CFArrayRef)[col->_exclusionDescriptors copy];
}

void CTFontCollectionSetQueryDescriptors(CTMutableFontCollectionRef collection, CFArrayRef descriptors)
{
    if (!collection) return;
    _CTFontCollection *col = (_CTFontCollection *)collection;
    [col->_queryDescriptors removeAllObjects];
    if (descriptors) {
        [col->_queryDescriptors addObjectsFromArray:(NSArray *)descriptors];
    }
}

void CTFontCollectionSetExclusionDescriptors(CTMutableFontCollectionRef collection, CFArrayRef descriptors)
{
    if (!collection) return;
    _CTFontCollection *col = (_CTFontCollection *)collection;
    [col->_exclusionDescriptors removeAllObjects];
    if (descriptors) {
        [col->_exclusionDescriptors addObjectsFromArray:(NSArray *)descriptors];
    }
}

CFArrayRef CTFontCollectionCopyFontAttribute(CTFontCollectionRef collection, CFStringRef attributeName, CTFontCollectionCopyOptions options)
{
    if (!collection || !attributeName) return NULL;
    CFArrayRef tmp = CTFontCollectionCreateMatchingFontDescriptors(collection);
    if (!tmp) return NULL;
    NSArray *descriptors = (NSArray *)tmp;
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = (options & kCTFontCollectionCopyUnique) ? [NSMutableSet set] : nil;
    for (id desc in descriptors) {
        id val = [attributesOf(desc) objectForKey:(id)attributeName];
        if (val) {
            if (seen) {
                if ([seen containsObject:val]) continue;
                [seen addObject:val];
            }
            [result addObject:val];
        }
    }
    if ((options & kCTFontCollectionCopyStandardSort) && result.count > 1) {
        [result sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            if ([obj1 respondsToSelector:@selector(compare:)] && [obj2 isKindOfClass:[obj1 class]]) {
                return [obj1 compare:obj2];
            }
            return NSOrderedSame;
        }];
    }
    CFArrayRef ret = (CFArrayRef)[result copy];
    CFRelease(tmp);
    return ret;
}

CFArrayRef CTFontCollectionCopyFontAttributes(CTFontCollectionRef collection, CFSetRef attributeNames, CTFontCollectionCopyOptions options)
{
    if (!collection || !attributeNames) return NULL;
    CFArrayRef tmp = CTFontCollectionCreateMatchingFontDescriptors(collection);
    if (!tmp) return NULL;
    NSArray *descriptors = (NSArray *)tmp;
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = (options & kCTFontCollectionCopyUnique) ? [NSMutableSet set] : nil;
    for (id desc in descriptors) {
        NSDictionary *descAttributes = attributesOf(desc);
        NSMutableDictionary *subDict = [NSMutableDictionary dictionary];
        for (id key in (NSSet *)attributeNames) {
            id val = [descAttributes objectForKey:key];
            if (val) subDict[key] = val;
        }
        if (subDict.count > 0) {
            if (seen) {
                // TODO: Apple deduplicates by font identity (PostScript name), not full dictionary equality.
                id identityKey = [descAttributes objectForKey:(id)kCTFontNameAttribute]
                    ?: [descAttributes objectForKey:(id)kCTFontPostScriptNameAttribute]
                    ?: subDict;
                if ([seen containsObject:identityKey]) continue;
                [seen addObject:identityKey];
            }
            [result addObject:subDict];
        }
    }
    if ((options & kCTFontCollectionCopyStandardSort) && result.count > 1) {
        [result sortUsingComparator:^NSComparisonResult(NSDictionary *d1, NSDictionary *d2) {
            NSString *n1 = [d1 objectForKey:(id)kCTFontNameAttribute] ?: [d1 objectForKey:(id)kCTFontFamilyNameAttribute];
            NSString *n2 = [d2 objectForKey:(id)kCTFontNameAttribute] ?: [d2 objectForKey:(id)kCTFontFamilyNameAttribute];
            if ([n1 isKindOfClass:[NSString class]] && [n2 isKindOfClass:[NSString class]]) {
                return [n1 compare:n2];
            }
            return NSOrderedSame;
        }];
    }
    CFArrayRef ret = (CFArrayRef)[result copy];
    CFRelease(tmp);
    return ret;
}
