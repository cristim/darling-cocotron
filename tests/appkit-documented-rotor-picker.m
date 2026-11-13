// NSAccessibilityCustomRotor and NSSharingServicePickerToolbarItem: class, metaclass, superclass, property types and documented behaviour.
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
        checkClass("NSAccessibilityCustomRotor", "NSObject");
        checkProperty("NSAccessibilityCustomRotor", "label", "@\"NSString\"");
        checkProperty("NSAccessibilityCustomRotor", "type", "q");
        NSAccessibilityCustomRotor *rotor = [[NSAccessibilityCustomRotor alloc] initWithLabel:@"Notes" itemSearchDelegate:nil];
        expect([rotor.label isEqual:@"Notes"] && rotor.type == NSAccessibilityCustomRotorTypeCustom, @"label rotor");
        rotor = [[NSAccessibilityCustomRotor alloc] initWithRotorType:NSAccessibilityCustomRotorTypeLink itemSearchDelegate:nil];
        expect(rotor.type == NSAccessibilityCustomRotorTypeLink, @"typed rotor");
        checkClass("NSSharingServicePickerToolbarItem", "NSToolbarItem");
        NSSharingServicePickerToolbarItem *picker = [[NSSharingServicePickerToolbarItem alloc] initWithItemIdentifier:@"p"];
        expect([picker.itemIdentifier isEqual:@"p"] && picker.delegate == nil, @"picker item identifier");
        printf("PASS: appkit-documented-rotor-picker\n");
    }
    return 0;
}
