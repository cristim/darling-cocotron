// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Runs the real key-view selection methods of AppKit/NSWindow.m in a mock NSWindow.
 *
 * tests/nswindow-key-view-direction-host.sh cuts the methods, the NSSelectionDirection typedef and the
 * _keyViewSelectionDirection ivar out of NSWindow.m / NSWindow.h. Apple documents keyViewSelectionDirection as
 * "the direction the window is currently using to change the key view": NSDirectSelection (0), NSSelectingNext
 * (1) or NSSelectingPrevious (2), an NSUInteger enum. So while -selectKeyViewFollowingView: (and Next) makes the
 * new key view first responder the window reports NSSelectingNext, while the Preceding/Previous pair does it
 * NSSelectingPrevious, and outside those NSDirectSelection. None of these methods, nor -isOnActiveSpace and
 * -setShowsResizeIndicator:, may log "unimplemented". */
#include <objc/runtime.h>
#include <stdio.h>

typedef unsigned long NSUInteger;
#define NS_ENUM(_type, _name) _type _name; enum
#include TYPEDEF_INC

static int unimplementedCalls;
#define NSUnimplementedMethod() (unimplementedCalls++)

__attribute__((objc_root_class))
@interface NSResponder {
    Class isa;
}
+ (id)alloc;
+ (Class)class;
- (id)init;
- (BOOL)isKindOfClass:(Class)cls;
@end

@implementation NSResponder
+ (id)alloc { return class_createInstance(self, 0); }
+ (Class)class { return self; }
- (id)init { return self; }
- (BOOL)isKindOfClass:(Class)cls
{
    for (Class c = object_getClass(self); c; c = class_getSuperclass(c))
        if (c == cls) return YES;
    return NO;
}
@end

@interface NSView : NSResponder {
@public
    NSView *_next, *_previous;
}
- (NSView *)nextValidKeyView;
- (NSView *)previousValidKeyView;
@end

@implementation NSView
- (NSView *)nextValidKeyView { return _next; }
- (NSView *)previousValidKeyView { return _previous; }
@end

@interface NSWindow : NSResponder {
@public
    NSResponder *_firstResponder;
    BOOL _showsResizeIndicator;
#include IVARS_INC
    NSSelectionDirection seenDirection;
    int firstResponderCalls;
}
- (BOOL)makeFirstResponder:(NSResponder *)responder;
- (NSSelectionDirection)keyViewSelectionDirection;
- (void)selectNextKeyView:(id)sender;
- (void)selectPreviousKeyView:(id)sender;
- (void)selectKeyViewFollowingView:(NSView *)view;
- (void)selectKeyViewPrecedingView:(NSView *)view;
- (BOOL)isOnActiveSpace;
- (BOOL)showsResizeIndicator;
- (void)setShowsResizeIndicator:(BOOL)value;
@end

@implementation NSWindow
// What a view sees from its -becomeFirstResponder.
- (BOOL)makeFirstResponder:(NSResponder *)responder
{
    firstResponderCalls++;
    seenDirection = [self keyViewSelectionDirection];
    _firstResponder = responder;
    return YES;
}
#include METHODS_INC
@end

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

int main(void)
{
    CK(sizeof(NSSelectionDirection) == sizeof(NSUInteger), "NSSelectionDirection is NSUInteger-sized (got %zu bytes)",
       sizeof(NSSelectionDirection));

    NSWindow *window = [[NSWindow alloc] init];
    NSView *a = [[NSView alloc] init], *b = [[NSView alloc] init], *c = [[NSView alloc] init];
    a->_next = b; b->_next = c; c->_next = a;
    a->_previous = c; b->_previous = a; c->_previous = b;
    window->_firstResponder = a;

    CK([window keyViewSelectionDirection] == 0, "direct selection (0) when no key-view change is under way");

    [window selectNextKeyView:nil];
    CK(window->_firstResponder == b, "selectNextKeyView: moves to the next valid key view");
    CK(window->seenDirection == 1, "the new key view sees NSSelectingNext (1) (got %lu)",
       (unsigned long)window->seenDirection);
    CK([window keyViewSelectionDirection] == 0, "back to direct selection afterwards (got %lu)",
       (unsigned long)[window keyViewSelectionDirection]);

    [window selectPreviousKeyView:nil];
    CK(window->_firstResponder == a, "selectPreviousKeyView: moves to the previous valid key view");
    CK(window->seenDirection == 2, "the new key view sees NSSelectingPrevious (2) (got %lu)",
       (unsigned long)window->seenDirection);

    [window selectKeyViewFollowingView:c];
    CK(window->_firstResponder == a && window->seenDirection == 1, "selectKeyViewFollowingView: selects next (got %lu)",
       (unsigned long)window->seenDirection);
    [window selectKeyViewPrecedingView:a];
    CK(window->_firstResponder == c && window->seenDirection == 2, "selectKeyViewPrecedingView: selects previous (got %lu)",
       (unsigned long)window->seenDirection);

    window->seenDirection = 99;
    [window makeFirstResponder:b];
    CK(window->seenDirection == 0, "a direct makeFirstResponder: sees NSDirectSelection (got %lu)",
       (unsigned long)window->seenDirection);

    CK([window isOnActiveSpace], "isOnActiveSpace: every window is on the one space");
    [window setShowsResizeIndicator:YES];
    CK([window showsResizeIndicator], "setShowsResizeIndicator: keeps the value");
    [window setShowsResizeIndicator:NO];
    CK(![window showsResizeIndicator], "setShowsResizeIndicator: NO keeps the value");

    CK(unimplementedCalls == 0, "nothing logs as unimplemented (%d calls)", unimplementedCalls);

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
