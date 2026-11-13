// NSMenuToolbarItem: a subclassable NSToolbarItem with a menu and an indicator flag.
#import <AppKit/AppKit.h>
#include <objc/runtime.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface Sub : NSMenuToolbarItem {
    long _extra;
}
@end
@implementation Sub
@end

int main(void)
{
    @autoreleasepool
    {
        NSMenuToolbarItem *item = [[NSMenuToolbarItem alloc] initWithItemIdentifier:@"menu"];
        expect([item isKindOfClass:[NSToolbarItem class]], @"is a toolbar item");
        expect([[item itemIdentifier] isEqualToString:@"menu"], @"keeps its identifier");
        expect(item.showsIndicator, @"indicator defaults to YES");
        expect(item.menu == nil, @"no menu by default");

        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"m"];
        item.menu = menu;
        item.showsIndicator = NO;
        expect(item.menu == menu && !item.showsIndicator, @"keeps what it is given");

        NSUInteger before = [menu retainCount];
        NSMenuToolbarItem *dup = [item copy];
        expect(!dup.showsIndicator, @"copy keeps the flag");
        NSUInteger afterCopy = [menu retainCount];
        expect(afterCopy == before + 1, @"the copy retains the menu");
        [dup release];
        NSUInteger afterRelease = [menu retainCount];
        expect(afterRelease == before, @"releasing the copy gives the retain back");
        expect(item.menu == menu, @"original keeps the menu");

        Sub *sub = [[Sub alloc] initWithItemIdentifier:@"sub"];
        expect(class_getSuperclass(object_getClass([Sub class])) == object_getClass([NSMenuToolbarItem class]),
               @"metaclass chain");
        expect(class_getInstanceSize([Sub class]) > class_getInstanceSize([NSMenuToolbarItem class]),
               @"subclass ivar is laid out after the superclass");
        expect(sub.showsIndicator, @"subclass inherits the default");

        [sub release];
        [menu release];
        [item release];
        NSLog(@"PASS: NSMenuToolbarItem");
    }
    return 0;
}
