// NSTintConfiguration and NSPathControlItem: class, metaclass, superclass, property types and documented behaviour.
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
        checkClass("NSTintConfiguration", "NSObject");
        checkClass("NSPathControlItem", "NSObject");
        checkProperty("NSTintConfiguration", "adaptsToUserAccentColor", "c");
        checkProperty("NSTintConfiguration", "baseTintColor", "@\"NSColor\"");
        checkProperty("NSPathControlItem", "title", "@\"NSString\"");
        checkProperty("NSPathControlItem", "URL", "@\"NSURL\"");

        NSColor *red = [NSColor redColor];
        NSTintConfiguration *fixed = [NSTintConfiguration tintConfigurationWithFixedColor:red];
        NSTintConfiguration *preferred = [NSTintConfiguration tintConfigurationWithPreferredColor:red];
        expect(fixed.baseTintColor == red && !fixed.adaptsToUserAccentColor, @"fixed tint keeps its color");
        expect(preferred.adaptsToUserAccentColor, @"preferred tint adapts to the accent color");
        expect([NSTintConfiguration defaultTintConfiguration] == [NSTintConfiguration defaultTintConfiguration],
               @"the default tint configuration is shared");
        expect([NSTintConfiguration monochromeTintConfiguration] != [NSTintConfiguration defaultTintConfiguration],
               @"monochrome differs from default");

        NSPathControlItem *item = [[NSPathControlItem alloc] init];
        item.title = @"Home";
        expect([item.title isEqual:@"Home"] && item.URL == nil, @"path item stores its title");
        printf("PASS: appkit-documented-tint-path\n");
    }
    return 0;
}
