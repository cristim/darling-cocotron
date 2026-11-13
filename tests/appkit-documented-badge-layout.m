// NSMenuItemBadge and NSScrubberLayoutAttributes: class, metaclass, superclass, property types and documented behaviour.
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
        checkClass("NSMenuItemBadge", "NSObject");
        checkClass("NSScrubberLayoutAttributes", "NSObject");
        checkProperty("NSMenuItemBadge", "itemCount", "q");
        checkProperty("NSMenuItemBadge", "stringValue", "@\"NSString\"");
        checkProperty("NSMenuItemBadge", "type", "q");
        checkProperty("NSScrubberLayoutAttributes", "itemIndex", "q");
        checkProperty("NSScrubberLayoutAttributes", "alpha", "d");

        NSMenuItemBadge *count = [[NSMenuItemBadge alloc] initWithCount:7];
        expect(count.itemCount == 7 && [count.stringValue isEqual:@""], @"a count badge has an empty string");
        NSMenuItemBadge *text = [[NSMenuItemBadge alloc] initWithString:@"new"];
        expect([text.stringValue isEqual:@"new"], @"a string badge keeps the string");
        expect([NSMenuItemBadge alertsWithCount:3].type == NSMenuItemBadgeTypeAlerts, @"alerts badge type");
        expect([NSMenuItemBadge updatesWithCount:3].itemCount == 3, @"updates badge count");
        expect([NSMenuItemBadge newItemsWithCount:1].type == NSMenuItemBadgeTypeNewItems, @"new items badge type");
        expect([NSMenuItemBadge updatesWithCount:1].type == NSMenuItemBadgeTypeUpdates, @"updates badge type");
        expect([[NSMenuItemBadge alloc] initWithCount:2 type:NSMenuItemBadgeTypeAlerts].type == NSMenuItemBadgeTypeAlerts, @"typed initializer");
        expect(count.type == NSMenuItemBadgeTypeNone, @"count badge has no type");

        NSScrubberLayoutAttributes *attrs = [NSScrubberLayoutAttributes layoutAttributesForItemAtIndex:4];
        expect(attrs.itemIndex == 4 && attrs.alpha == 1.0, @"layout attributes index and default alpha");
        attrs.frame = NSMakeRect(1, 2, 3, 4);
        NSScrubberLayoutAttributes *copy = [attrs copy];
        expect(NSEqualRects(copy.frame, attrs.frame) && copy.itemIndex == 4, @"layout attributes copy");
        printf("PASS: appkit-documented-badge-layout\n");
    }
    return 0;
}
