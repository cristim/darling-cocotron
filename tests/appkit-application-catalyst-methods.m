#import <AppKit/AppKit.h>
#include <objc/runtime.h>
#include <stdlib.h>

// Private AppKit API that Mac Catalyst frameworks require. Windows are fakes
// that model what -orderedWindows does (front to back, activating a window moves
// it to the front), so no window server is needed.
static int failures;

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        failures++;
    }
}

@interface NSApplication (CatalystPrivate)
- (NSWindow *)_findWindowUsingContextID:(uint32_t)contextID;
- (BOOL)_restoreMiniaturizedWindow;
- (void)_cycleWindowsReversed:(BOOL)reversed;
- (void)_addDebugMenuIfNeeded;
@end

static NSMutableArray *gOrder;
static id gKey;

@interface FakeWindow : NSObject
{
@public
    NSString *name;
    BOOL visible, miniaturized, canBeKey, restored;
}
@end

@implementation FakeWindow
- (BOOL)isVisible { return visible; }
- (BOOL)isMiniaturized { return miniaturized; }
- (BOOL)canBecomeKeyWindow { return canBeKey; }
- (void)deminiaturize:(id)sender { restored = YES; miniaturized = NO; }
- (void)makeKeyAndOrderFront:(id)sender
{
    [gOrder removeObjectIdenticalTo:self];
    [gOrder insertObject:self atIndex:0];
    gKey = self;
}
- (void)orderBack:(id)sender
{
    [gOrder removeObjectIdenticalTo:self];
    [gOrder addObject:self];
}
@end

static FakeWindow *fake(NSString *name)
{
    FakeWindow *w = [[[FakeWindow alloc] init] autorelease];
    w->name = name;
    w->visible = YES;
    w->canBeKey = YES;
    return w;
}

static NSString *cycle(NSApplication *app, BOOL reversed, int steps)
{
    NSMutableString *seq = [NSMutableString string];
    for (int i = 0; i < steps; i++)
    {
        [app _cycleWindowsReversed:reversed];
        [seq appendString:((FakeWindow *)gKey)->name];
    }
    return seq;
}

@interface Helper : NSObject
- (void)copy:(id)sender;
@end
@implementation Helper
- (void)copy:(id)sender {}
@end

@interface SupplementalResponder : NSResponder
@property (retain) id helper;
@end
@implementation SupplementalResponder
- (id)supplementalTargetForAction:(SEL)action sender:(id)sender
{
    return action == @selector(copy:) ? _helper : [super supplementalTargetForAction:action sender:sender];
}
@end


int main(void)
{
    @autoreleasepool
    {
        NSApplication *app = [NSApplication sharedApplication];

        // -_findWindowUsingContextID: Cocotron has no context ids, so no window is ever found.
        expect([app respondsToSelector:@selector(_findWindowUsingContextID:)],
               @"NSApplication answers -_findWindowUsingContextID:");
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES];
        expect([app _findWindowUsingContextID:(uint32_t)[window windowNumber]] == nil,
               @"a window number is not a context id");
        expect([app _findWindowUsingContextID:(uint32_t)[app contextID]] == nil,
               @"the application's context id finds no window");
        [window release];

        // Fake window model from here on.
        method_setImplementation(class_getInstanceMethod([NSApplication class], @selector(orderedWindows)),
                                 imp_implementationWithBlock(^NSArray *(id s) { return [[gOrder copy] autorelease]; }));
        method_setImplementation(class_getInstanceMethod([NSApplication class], @selector(keyWindow)),
                                 imp_implementationWithBlock(^id(id s) { return gKey; }));

        // -_restoreMiniaturizedWindow restores the frontmost miniaturized window only.
        expect([app respondsToSelector:@selector(_restoreMiniaturizedWindow)],
               @"NSApplication answers -_restoreMiniaturizedWindow");
        FakeWindow *front = fake(@"front"), *mid = fake(@"mid"), *back = fake(@"back");
        gOrder = [[NSMutableArray alloc] initWithObjects:front, mid, back, nil];
        expect(![app _restoreMiniaturizedWindow], @"nothing is restored when no window is miniaturized");
        mid->miniaturized = back->miniaturized = YES;
        expect([app _restoreMiniaturizedWindow] && mid->restored && !back->restored,
               @"the frontmost miniaturized window is restored, and only it");
        [gOrder release];

        // -_cycleWindowsReversed:
        expect([app respondsToSelector:@selector(_cycleWindowsReversed:)],
               @"NSApplication answers -_cycleWindowsReversed:");
        FakeWindow *a = fake(@"A"), *b = fake(@"B"), *c = fake(@"C");
        gOrder = [[NSMutableArray alloc] initWithObjects:a, b, c, nil];
        gKey = a;
        NSString *forward = cycle(app, NO, 6);
        expect([forward isEqual:@"CBACBA"], [NSString stringWithFormat:@"forward cycling visits every window: %@", forward]);
        gOrder = [[NSMutableArray alloc] initWithObjects:a, b, c, nil];
        gKey = a;
        NSString *reversed = cycle(app, YES, 6);
        expect([reversed isEqual:@"BCABCA"], [NSString stringWithFormat:@"reversed cycling visits every window: %@", reversed]);

        FakeWindow *hidden = fake(@"H"), *mini = fake(@"M"), *nokey = fake(@"N");
        hidden->visible = NO;
        mini->miniaturized = YES;
        nokey->canBeKey = NO;
        gOrder = [[NSMutableArray alloc] initWithObjects:hidden, a, mini, nokey, b, nil];
        gKey = a;
        expect([cycle(app, NO, 4) isEqual:@"BABA"], @"only visible key-capable windows take part");
        gOrder = [[NSMutableArray alloc] initWithObjects:hidden, mini, nil];
        gKey = nil;
        [app _cycleWindowsReversed:NO];
        [app _cycleWindowsReversed:YES];
        expect(gKey == nil, @"with no candidate nothing becomes key");
        gOrder = [[NSMutableArray alloc] initWithObjects:a, nil];
        gKey = a;
        [app _cycleWindowsReversed:YES];
        [app _cycleWindowsReversed:NO];
        expect(gKey == a && [gOrder count] == 1, @"a single window stays key");

        gKey = nil; // -_addDebugMenuIfNeeded leaves the main menu alone.
        expect([app respondsToSelector:@selector(_addDebugMenuIfNeeded)],
               @"NSApplication answers -_addDebugMenuIfNeeded");
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"main"];
        [app setMainMenu:menu];
        [app _addDebugMenuIfNeeded];
        expect([app mainMenu] == menu && [menu numberOfItems] == 0, @"no debug menu is added");
        [app setMainMenu:nil];
        [menu release];

        // -supplementalTargetForAction:sender: is nil from NSResponder; an override answers for itself only.
        expect([app respondsToSelector:@selector(supplementalTargetForAction:sender:)],
               @"NSApplication answers -supplementalTargetForAction:sender:");
        expect([app supplementalTargetForAction:@selector(copy:) sender:nil] == nil,
               @"NSApplication has no supplemental target");
        NSResponder *first = [[NSResponder alloc] init];
        NSResponder *middle = [[NSResponder alloc] init];
        SupplementalResponder *last = [[SupplementalResponder alloc] init];
        last.helper = [[[Helper alloc] init] autorelease];
        [first setNextResponder:middle];
        [middle setNextResponder:last];
        expect([first supplementalTargetForAction:@selector(copy:) sender:nil] == nil,
               @"NSResponder returns nil, whatever follows it in the chain");
        expect([middle supplementalTargetForAction:@selector(copy:) sender:nil] == nil,
               @"NSResponder returns nil for a responder before an override");
        expect([last supplementalTargetForAction:@selector(copy:) sender:nil] == last.helper,
               @"the override answers for itself");
        expect([last supplementalTargetForAction:@selector(paste:) sender:nil] == nil,
               @"the override falls back to nil for other actions");
        [first release];
        [middle release];
        [last release];




        if (failures == 0)
            NSLog(@"PASS: NSApplication catalyst methods");
    }
    return failures == 0 ? 0 : 1;
}
