#import <AppKit/AppKitExport.h>
#import <Foundation/NSString.h>

#import <AppKit/NSAccessibilityConstants.h>
#import <AppKit/NSAccessibilityProtocols.h>

APPKIT_EXPORT void NSAccessibilityPostNotification(id element,
                                                   NSString *notification);

APPKIT_EXPORT NSString *NSAccessibilityRoleDescription(NSString *role,
                                                       NSString *subrole);
APPKIT_EXPORT NSString *NSAccessibilityRoleDescriptionForUIElement(id element);
APPKIT_EXPORT NSString *
NSAccessibilityActionDescription(NSAccessibilityActionName action);
APPKIT_EXPORT void NSAccessibilityRaiseBadArgumentException(id element,
                                                            NSString *attribute,
                                                            id value);

// Private: AppKit exports them but they are not in the public documentation. GUESS (not in the public documentation,
// not observed): all seven signatures. The open-source OpenSwiftUI project's own shim declares four of them
// (provenance unconfirmed); none of the three others has any declaration. Each forwards to the element's own
// accessibility method; see NSAccessibility.m.
APPKIT_EXPORT NSArray *NSAccessibilityEntryPointAttributeNames(id element);
APPKIT_EXPORT id NSAccessibilityEntryPointValueForAttribute(id element, NSString *attribute);
APPKIT_EXPORT BOOL NSAccessibilityEntryPointIsAccessibilityElement(id element);
APPKIT_EXPORT BOOL NSAccessibilityEntryPointIsAttributeSupported(id element, NSString *attribute);
APPKIT_EXPORT NSArray *NSAccessibilityEntryPointActionNames(id element);
APPKIT_EXPORT NSString *NSAccessibilityEntryPointActionDescription(id element, NSString *action);
APPKIT_EXPORT BOOL NSAccessibilityEntryPointPerformAction(id element, NSString *action);

APPKIT_EXPORT id NSAccessibilityUnignoredAncestor(id element);
APPKIT_EXPORT id NSAccessibilityUnignoredDescendant(id element);
APPKIT_EXPORT NSArray *NSAccessibilityUnignoredChildren(NSArray *originalChildren);
APPKIT_EXPORT NSArray *NSAccessibilityUnignoredChildrenForOnlyChild(id originalChild);

// There is no accessibility server: objects have no attributes and overrides
// aren't kept.
@interface NSObject (NSAccessibility)
- (NSArray *) accessibilityAttributeNames;
- accessibilityAttributeValue: (NSString *) attribute;
- (BOOL) accessibilitySetOverrideValue: (id) value forAttribute: (NSString *) attribute;

@property(getter=isAccessibilityElement) BOOL accessibilityElement;
@property(copy) NSString *accessibilityLabel;
@property(copy) NSString *accessibilityHelp;
@property(copy) id accessibilityValue;
@property(copy) NSString *accessibilityTitle;
@property(copy) NSString *accessibilityIdentifier;
@end
