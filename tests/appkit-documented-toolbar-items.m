// NSButtonTouchBarItem and NSStepperTouchBarItem: class, metaclass, superclass, property types and documented behaviour.
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
        checkClass("NSButtonTouchBarItem", "NSTouchBarItem");
        checkClass("NSStepperTouchBarItem", "NSTouchBarItem");
        checkProperty("NSButtonTouchBarItem", "title", "@\"NSString\"");
        checkProperty("NSButtonTouchBarItem", "enabled", @encode(BOOL));
        checkProperty("NSButtonTouchBarItem", "action", ":");
        checkProperty("NSStepperTouchBarItem", "maxValue", "d");
        checkProperty("NSStepperTouchBarItem", "customizationLabel", "@\"NSString\"");

        id target = [NSObject new];
        NSButtonTouchBarItem *button =
            [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier:@"b" title:@"Go" target:target action:@selector(description)];
        expect([button.identifier isEqual:@"b"] && [button.title isEqual:@"Go"], @"button identifier and title");
        expect(button.target == target && button.action == @selector(description), @"button target and action");
        expect(button.enabled && [button.customizationLabel isEqual:@""], @"button defaults");
        button.customizationLabel = nil;
        expect([button.customizationLabel isEqual:@""], @"a nil customization label resets to empty");

        NSStepperTouchBarItem *stepper = [NSStepperTouchBarItem stepperTouchBarItemWithIdentifier:@"s" formatter:nil];
        expect(stepper.minValue == 0.0 && stepper.maxValue == 59.0 && stepper.increment == 1.0,
               @"documented stepper defaults");
        stepper.value = 12.5;
        expect(stepper.value == 12.5, @"stepper value");

        printf("PASS: appkit-documented-toolbar-items\n");
    }
    return 0;
}
