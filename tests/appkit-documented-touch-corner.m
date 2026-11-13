// NSTouch and NSViewCornerConfiguration: class, metaclass, superclass, property types and documented behaviour.
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
        checkClass("NSTouch", "NSObject");
        checkClass("NSViewCornerConfiguration", "NSObject");
        checkProperty("NSTouch", "phase", "Q");
        checkProperty("NSTouch", "resting", "c");
        checkProperty("NSTouch", "deviceSize", "{CGSize=dd}");

        NSTouch *touch = [[NSTouch alloc] init];
        expect(touch.phase == 0 && !touch.resting && touch.device == nil, @"a new touch is zeroed");
        expect(NSTouchTypeMaskFromType(NSTouchTypeIndirect) == NSTouchTypeMaskIndirect, @"touch type mask");
        expect([NSViewCornerConfiguration capsuleCornerConfiguration] != nil, @"capsule configuration exists");
        expect([NSViewCornerConfiguration configurationWithUniformRadius:nil] != nil, @"uniform configuration exists");
        printf("PASS: appkit-documented-touch-corner\n");
    }
    return 0;
}
