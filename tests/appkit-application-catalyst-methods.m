#import <AppKit/AppKit.h>
#include <objc/runtime.h>
#include <stdlib.h>

// Private NSApplication methods that Mac Catalyst frameworks require.
static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface NSApplication (CatalystPrivate)
- (NSWindow *)_findWindowUsingContextID:(uint32_t)contextID;
- (BOOL)_restoreMiniaturizedWindow;
- (void)_cycleWindowsReversed:(BOOL)reversed;
- (void)_addDebugMenuIfNeeded;
- (BOOL)_isActiveApp;
@end

int main(void)
{
    @autoreleasepool
    {
        NSApplication *app = [NSApplication sharedApplication];

        expect([app respondsToSelector:@selector(_findWindowUsingContextID:)],
               @"NSApplication answers -_findWindowUsingContextID:");
        expect([app _findWindowUsingContextID:0x7ffffff0] == nil, @"an unknown context id finds no window");

        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES];
        expect([app _findWindowUsingContextID:(uint32_t)[window windowNumber]] == window,
               @"the context id of a window is its window number");
        [window release];

        expect([app respondsToSelector:@selector(_restoreMiniaturizedWindow)],
               @"NSApplication answers -_restoreMiniaturizedWindow");
        expect(![app _restoreMiniaturizedWindow], @"with no miniaturized window nothing is restored");

        expect([app respondsToSelector:@selector(_cycleWindowsReversed:)],
               @"NSApplication answers -_cycleWindowsReversed:");
        [app _cycleWindowsReversed:NO];
        [app _cycleWindowsReversed:YES];

        expect([app respondsToSelector:@selector(_addDebugMenuIfNeeded)],
               @"NSApplication answers -_addDebugMenuIfNeeded");
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"main"];
        [app setMainMenu:menu];
        [app _addDebugMenuIfNeeded];
        expect([app mainMenu] == menu && [menu numberOfItems] == 0, @"no debug menu is added");
        [app setMainMenu:nil];
        [menu release];

        expect([app respondsToSelector:@selector(supplementalTargetForAction:sender:)],
               @"NSApplication answers -supplementalTargetForAction:sender:");
        expect([app supplementalTargetForAction:@selector(copy:) sender:nil] == nil,
               @"the end of the responder chain has no supplemental target");
        NSResponder *first = [[NSResponder alloc] init];
        NSResponder *second = [[NSResponder alloc] init];
        [first setNextResponder:second];
        expect([first supplementalTargetForAction:@selector(copy:) sender:nil] == nil,
               @"a chain of plain responders has no supplemental target");
        [first release];
        [second release];

        expect([app respondsToSelector:@selector(_isActiveApp)], @"NSApplication answers -_isActiveApp");
        expect([app _isActiveApp] == [app isActive], @"-_isActiveApp agrees with -isActive");

        Class pickerClass = NSClassFromString(@"NSSharingServicePickerToolbarItem");
        expect(pickerClass != Nil && [pickerClass isSubclassOfClass:[NSToolbarItem class]],
               @"NSSharingServicePickerToolbarItem is an NSToolbarItem subclass");
        expect(class_getInstanceMethod(pickerClass, @selector(validate)) != NULL,
               @"NSSharingServicePickerToolbarItem resolves -validate");
        NSToolbarItem *picker = [[pickerClass alloc] initWithItemIdentifier:@"share"];
        id delegate = [[NSObject alloc] init];
        [(id)picker setDelegate:delegate];
        expect([(id)picker delegate] == delegate, @"the picker item keeps its delegate");
        [picker validate];
        expect(class_getInstanceMethod(pickerClass, @selector(share:)) != NULL,
               @"NSSharingServicePickerToolbarItem resolves -share:");
        [(id)picker share:nil];
        [picker release];
        [delegate release];

        NSLog(@"PASS: NSApplication catalyst methods");
    }
    return 0;
}
