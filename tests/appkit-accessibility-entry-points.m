#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// GUESS (not in the public documentation, not observed): the private NSAccessibilityEntryPoint* functions App Store
// imports forward to the element's own accessibility methods. Every EXPECT below pins that guess; none is a Mac
// observation. A plain object answers "no attributes, no actions"; an element that implements the methods answers
// what they answer.
@interface Element : NSObject
@property(assign) NSInteger performed;
@end

@implementation Element
- (NSArray *) accessibilityAttributeNames { return @[ @"AXRole", @"AXTitle" ]; }
- accessibilityAttributeValue: (NSString *) attribute { return [attribute isEqual: @"AXTitle"] ? @"Get" : nil; }
- (BOOL) isAccessibilityElement { return YES; }
- (NSArray *) accessibilityActionNames { return @[ @"AXShowMenu" ]; }
- (NSString *) accessibilityActionDescription: (NSString *) action { return @"show menu"; }
- (void) accessibilityPerformAction: (NSString *) action { self.performed++; }
@end

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSArray *(*attributeNames)(id) = dlsym(RTLD_DEFAULT, "NSAccessibilityEntryPointAttributeNames");
    id (*valueForAttribute)(id, NSString *) = dlsym(RTLD_DEFAULT, "NSAccessibilityEntryPointValueForAttribute");
    BOOL (*isElement)(id) = dlsym(RTLD_DEFAULT, "NSAccessibilityEntryPointIsAccessibilityElement");
    BOOL (*isSupported)(id, NSString *) = dlsym(RTLD_DEFAULT, "NSAccessibilityEntryPointIsAttributeSupported");
    NSArray *(*actionNames)(id) = dlsym(RTLD_DEFAULT, "NSAccessibilityEntryPointActionNames");
    NSString *(*actionDescription)(id, NSString *) = dlsym(RTLD_DEFAULT, "NSAccessibilityEntryPointActionDescription");
    BOOL (*performAction)(id, NSString *) = dlsym(RTLD_DEFAULT, "NSAccessibilityEntryPointPerformAction");
    EXPECT(attributeNames && valueForAttribute && isElement && isSupported && actionNames && actionDescription &&
           performAction, "GUESS: all seven entry points are exported");

    id plain = [NSObject new];
    EXPECT([attributeNames(plain) count] == 0, "GUESS: a plain object has no attribute names");
    EXPECT(valueForAttribute(plain, @"AXTitle") == nil, "GUESS: a plain object has no attribute value");
    EXPECT(!isElement(plain), "GUESS: a plain object is not an accessibility element");
    EXPECT(!isSupported(plain, @"AXTitle"), "GUESS: a plain object supports no attribute");
    EXPECT(actionNames(plain) == nil, "GUESS: a plain object has no action names (nil)");
    EXPECT(actionDescription(plain, @"AXPress") == nil, "GUESS: a plain object describes no action (nil)");
    EXPECT(!performAction(plain, @"AXPress"), "GUESS: a plain object performs no action (NO)");

    Element *element = [Element new];
    EXPECT([attributeNames(element) isEqual: (@[ @"AXRole", @"AXTitle" ])],
           "GUESS: the attribute names are the element's own");
    EXPECT([valueForAttribute(element, @"AXTitle") isEqual: @"Get"], "GUESS: the value is the element's own");
    EXPECT(valueForAttribute(element, @"AXRole") == nil, "GUESS: an attribute without a value gives nil");
    EXPECT(isElement(element), "GUESS: the element answers isAccessibilityElement");
    EXPECT(isSupported(element, @"AXRole"), "GUESS: a listed attribute is supported");
    EXPECT(!isSupported(element, @"AXHelp"), "GUESS: an unlisted attribute is not supported");
    EXPECT([actionNames(element) isEqual: @[ @"AXShowMenu" ]], "GUESS: the action names are the element's own");
    EXPECT([actionDescription(element, @"AXShowMenu") isEqual: @"show menu"],
           "GUESS: the description is the element's own");
    EXPECT(performAction(element, @"AXShowMenu") && element.performed == 1,
           "GUESS: a listed action is performed once and answers YES");
    EXPECT(!performAction(element, @"AXPress") && element.performed == 1,
           "GUESS: an unlisted action is not performed and answers NO");

    EXPECT([attributeNames(nil) count] == 0 && valueForAttribute(nil, @"AXTitle") == nil && !isElement(nil) &&
               !isSupported(nil, @"AXTitle") && actionNames(nil) == nil && !performAction(nil, @"AXPress"),
           "GUESS: a nil element answers nothing, as messaging nil does");
    [pool drain];
    printf("PASS: GUESS: the NSAccessibilityEntryPoint functions forward to the element's accessibility methods\n");
    return 0;
}
