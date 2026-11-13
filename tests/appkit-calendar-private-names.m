// The AppKit names Calendar binds that have no public documentation exist: four
// stub classes (superclasses are guesses) whose unimplemented messages are ignored,
// three string constants and one function.
#import <AppKit/AppKit.h>
#include <stdlib.h>

extern NSString *const NSAccessibilityDateTimeComponentsAttribute;
extern NSString *const NSAccessibilityOpenAction;
extern NSString *const NSSharingServiceParametersDefaultRecipientsKey;
extern NSInteger NSSidebarMetricsForRowSize(NSInteger rowSizeStyle);

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSArray *viewNames = @[ @"NSBannerView", @"NSPopoverFrame" ];
        NSArray *objectNames = @[ @"NSPopoverAnimationController", @"NSToolbarItemBadge" ];
        for (NSString *name in [viewNames arrayByAddingObjectsFromArray: objectNames])
        {
            Class cls = NSClassFromString(name);
            expect(cls != Nil, [name stringByAppendingString: @" exists"]);
            BOOL isView = [viewNames containsObject: name];
            expect(isView ? [cls isSubclassOfClass: [NSView class]] : [cls superclass] == [NSObject class],
                   [name stringByAppendingString: @" has the guessed superclass"]);
            id instance = isView ? [[cls alloc] initWithFrame: NSMakeRect(0, 0, 10, 10)] : [[cls alloc] init];
            expect(instance != nil, [name stringByAppendingString: @" can be created"]);
            expect([instance respondsToSelector: @selector(retain)], @"real methods still work");
            [instance performSelector: NSSelectorFromString(@"someUnimplementedMessage")];
            [instance release];
        }

        expect([NSAccessibilityDateTimeComponentsAttribute length] > 0 && [NSAccessibilityOpenAction length] > 0 &&
                   [NSSharingServiceParametersDefaultRecipientsKey length] > 0,
               @"the constants are non-empty");
        expect(![NSAccessibilityOpenAction isEqual: NSAccessibilityPressAction], @"OpenAction differs from PressAction");
        expect(NSSidebarMetricsForRowSize(2) == 0, @"the function returns the documented placeholder");
        NSLog(@"PASS: calendar private names");
    }
    return 0;
}
