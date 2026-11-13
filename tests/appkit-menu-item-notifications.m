// NSMenu posts NSMenuDidAddItemNotification after an insert and
// NSMenuDidChangeItemNotification after an item's title, state or enabled flag changes.
// Both carry the item's index under NSMenuItemIndex (documented key).
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

// Records what each notification carried while it is delivered: the object and the index.
@interface Spy : NSObject
@property (retain) NSMutableArray *adds, *changes;
@property (assign) id lastObject;
@end
@implementation Spy
- (void)record:(NSNotification *)n into:(NSMutableArray *)list
{
    self.lastObject = [n object];
    [list addObject:[[n userInfo] objectForKey:@"NSMenuItemIndex"]];
}
- (void)added:(NSNotification *)n { [self record:n into:self.adds]; }
- (void)changed:(NSNotification *)n { [self record:n into:self.changes]; }
@end

int main(void)
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        Spy *spy = [[[Spy alloc] init] autorelease];
        spy.adds = [NSMutableArray array];
        spy.changes = [NSMutableArray array];
        NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"M"] autorelease];
        [menu setAutoenablesItems:NO];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:spy selector:@selector(added:) name:NSMenuDidAddItemNotification object:menu];
        [center addObserver:spy selector:@selector(changed:) name:NSMenuDidChangeItemNotification object:menu];

        NSMenuItem *first = [[[NSMenuItem alloc] initWithTitle:@"A" action:NULL keyEquivalent:@""] autorelease];
        NSMenuItem *second = [[[NSMenuItem alloc] initWithTitle:@"B" action:NULL keyEquivalent:@""] autorelease];
        [menu addItem:first];
        [menu insertItem:second atIndex:0];
        expect([spy.adds count] == 2, @"one add notification per insert");
        expect([spy.adds[0] integerValue] == 0, @"first add at 0");
        expect([spy.adds[1] integerValue] == 0, @"second add at 0");
        expect(spy.lastObject == menu, @"the object is the menu");
        expect([spy.changes count] == 0, @"adding is not a change");

        [first setTitle:@"A2"];
        expect([spy.changes count] == 1, @"title change notifies");
        expect([spy.changes[0] integerValue] == 1,
               @"the change carries the item index");
        [first setState:NSControlStateValueOn];
        [first setState:NSControlStateValueOn];
        expect([spy.changes count] == 2, @"state change notifies once, a repeat does not");
        [first setEnabled:NO];
        [first setEnabled:NO];
        expect([spy.changes count] == 3, @"enabled change notifies once, a repeat does not");

        NSMenuItem *loose = [[[NSMenuItem alloc] initWithTitle:@"L" action:NULL keyEquivalent:@""] autorelease];
        [loose setTitle:@"L2"];
        expect([spy.changes count] == 3, @"an item outside the menu posts nothing");

        NSLog(@"PASS: menu item notifications");
    }
    return 0;
}
