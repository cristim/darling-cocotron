// NSAccessibilityCustomRotor and NSWritingToolsCoordinator: class, metaclass, superclass, property types and documented behaviour.
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
        checkClass("NSWritingToolsCoordinator", "NSObject");
        checkProperty("NSAccessibilityCustomRotor", "label", "@\"NSString\"");
        checkProperty("NSAccessibilityCustomRotor", "type", "q");
        checkProperty("NSWritingToolsCoordinator", "preferredBehavior", "q");
        checkProperty("NSWritingToolsCoordinator", "preferredResultOptions", "Q");
        checkProperty("NSWritingToolsCoordinator", "includesTextListMarkers", "c");
        checkProperty("NSWritingToolsCoordinator", "state", "q");

        NSAccessibilityCustomRotor *rotor = [[NSAccessibilityCustomRotor alloc] initWithLabel:@"Notes" itemSearchDelegate:nil];
        expect([rotor.label isEqual:@"Notes"] && rotor.type == NSAccessibilityCustomRotorTypeCustom, @"label rotor");
        rotor = [[NSAccessibilityCustomRotor alloc] initWithRotorType:NSAccessibilityCustomRotorTypeLink itemSearchDelegate:nil];
        expect(rotor.type == NSAccessibilityCustomRotorTypeLink, @"typed rotor");

        NSWritingToolsCoordinator *coordinator = [[NSWritingToolsCoordinator alloc] initWithDelegate:nil];
        expect(![NSWritingToolsCoordinator isWritingToolsAvailable], @"Writing Tools is unavailable");
        expect(coordinator.preferredBehavior == NSWritingToolsBehaviorDefault, @"preferred behavior default");
        expect(coordinator.state == NSWritingToolsCoordinatorStateInactive && coordinator.view == nil, @"inactive coordinator");
        expect([coordinator startTextAnimation:NSWritingToolsCoordinatorTextAnimationInsert
                                      forRange:NSMakeRange(0, 1)
                                     inContext:nil
                              writingDirection:NSWritingDirectionNatural] == nil, @"no animation id");
        printf("PASS: appkit-documented-rotor-writing-tools\n");
    }
    return 0;
}
