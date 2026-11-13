// NSFontCollection and NSMutableFontCollection, served from CoreText: class, metaclass, superclass, property types and documented behaviour.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static void checkClass(const char *name, const char *superName)
{
    Class cls = objc_getClass(name);
    NSString *label = [NSString stringWithUTF8String:name];
    expect(cls != Nil, [label stringByAppendingString:@" exists"]);
    expect(class_isMetaClass(object_getClass(cls)), [label stringByAppendingString:@" has a metaclass"]);
    expect(class_getSuperclass(cls) == objc_getClass(superName),
           [label stringByAppendingFormat:@" has superclass %s", superName]);
}

static void checkProperty(const char *name, const char *property, const char *type)
{
    objc_property_t p = class_getProperty(objc_getClass(name), property);
    NSString *label = [NSString stringWithFormat:@"%s.%s", name, property];
    expect(p != NULL, [label stringByAppendingString:@" is declared"]);
    char *t = property_copyAttributeValue(p, "T");
    BOOL same = t != NULL && strcmp(t, type) == 0;
    NSString *got = t ? [NSString stringWithUTF8String:t] : @"(none)";
    free(t);
    expect(same, [label stringByAppendingFormat:@" has type %s, got %@", type, got]);
}

int main(void)
{
    @autoreleasepool
    {
        checkClass("NSFontCollection", "NSObject");
        checkClass("NSMutableFontCollection", "NSFontCollection");
        checkProperty("NSFontCollection", "queryDescriptors", "@\"NSArray\"");
        checkProperty("NSFontCollection", "matchingDescriptors", "@\"NSArray\"");
        checkProperty("NSMutableFontCollection", "queryDescriptors", "@\"NSArray\"");
        expect(NSFontCollectionVisibilityProcess != NSFontCollectionVisibilityUser, @"visibility constants differ");

        NSArray *query = @[ [NSObject new] ];
        NSFontCollection *collection = [NSFontCollection fontCollectionWithDescriptors:query];
        expect([collection.queryDescriptors isEqual:query], @"the query is kept");
        expect(collection.exclusionDescriptors == nil, @"no exclusions by default");
        expect([collection.matchingDescriptors count] == 0, @"matching is empty without font matching");

        NSMutableFontCollection *mutableCollection = [collection mutableCopy];
        expect([mutableCollection isKindOfClass:[NSMutableFontCollection class]], @"mutableCopy is mutable");
        id extra = [NSObject new];
        [mutableCollection addQueryForDescriptors:@[ extra ]];
        expect([mutableCollection.queryDescriptors count] == 2 && [collection.queryDescriptors count] == 1,
               @"adding a query changes only the mutable copy");
        [mutableCollection removeQueryForDescriptors:@[ extra ]];
        expect([mutableCollection.queryDescriptors count] == 1, @"removing a query");
        expect([[NSMutableFontCollection fontCollectionWithName:@"x"] isKindOfClass:[NSMutableFontCollection class]],
               @"mutable factories return mutable collections");
        printf("PASS: appkit-documented-font-collections\n");
    }
    return 0;
}
