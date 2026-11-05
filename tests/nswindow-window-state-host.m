// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Checks that NSWindow keeps collectionBehavior and tabbingMode per window.
 *
 * tests/nswindow-window-state-host.sh cuts the declarations of _collectionBehavior and _tabbingMode out of
 * wherever NSWindow.h / NSWindow.m put them, and the four accessors out of NSWindow.m. Apple documents both as
 * properties of a window ("A value that identifies the window's behavior in window collections", "The preferred
 * tabbing mode for the window"), so setting one window's value must leave every other window's alone. A
 * declaration written at the top of @implementation without braces is a file-scope variable shared by all windows,
 * which this test detects. */
#include <objc/runtime.h>
#include <stdio.h>

typedef unsigned long NSUInteger;
typedef NSUInteger NSWindowCollectionBehavior;
typedef NSUInteger NSWindowTabbingMode;
enum {
    NSWindowCollectionBehaviorCanJoinAllSpaces = 0x01,
    NSWindowCollectionBehaviorMoveToActiveSpace = 0x02,
    NSWindowCollectionBehaviorTransient = 0x08,
};
enum { NSWindowTabbingModeAutomatic = 0, NSWindowTabbingModePreferred, NSWindowTabbingModeDisallowed };

__attribute__((objc_root_class))
@interface NSResponder {
    Class isa;
}
+ (id)alloc;
- (id)init;
@end

@implementation NSResponder
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { return self; }
@end

@interface NSWindow : NSResponder {
#include IVARS_INC
}
- (NSWindowCollectionBehavior)collectionBehavior;
- (void)setCollectionBehavior:(NSWindowCollectionBehavior)behavior;
- (NSWindowTabbingMode)tabbingMode;
- (void)setTabbingMode:(NSWindowTabbingMode)tabbingMode;
@end

@implementation NSWindow
#include PROLOGUE_INC
#include METHODS_INC
@end

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

int main(void)
{
    NSWindow *a = [[NSWindow alloc] init], *b = [[NSWindow alloc] init];

    CK([a collectionBehavior] == 0 && [b collectionBehavior] == 0, "new windows start with the default behavior (0)");
    [a setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient];
    CK([a collectionBehavior] == (NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient),
       "a window reads back the behavior it was given");
    CK([b collectionBehavior] == 0, "setting one window's behavior leaves another's alone (got %lu)",
       (unsigned long)[b collectionBehavior]);
    [b setCollectionBehavior:NSWindowCollectionBehaviorMoveToActiveSpace];
    CK([a collectionBehavior] == (NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient),
       "the first window keeps its behavior after another is set (got %lu)", (unsigned long)[a collectionBehavior]);
    NSWindow *c = [[NSWindow alloc] init];
    CK([c collectionBehavior] == 0, "a window created later starts at the default (got %lu)",
       (unsigned long)[c collectionBehavior]);

    CK([a tabbingMode] == NSWindowTabbingModeAutomatic, "new windows start with automatic tabbing");
    [a setTabbingMode:NSWindowTabbingModeDisallowed];
    CK([a tabbingMode] == NSWindowTabbingModeDisallowed, "a window reads back its tabbing mode");
    CK([b tabbingMode] == NSWindowTabbingModeAutomatic && [c tabbingMode] == NSWindowTabbingModeAutomatic,
       "setting one window's tabbing mode leaves the others alone (got %lu, %lu)",
       (unsigned long)[b tabbingMode], (unsigned long)[c tabbingMode]);

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
