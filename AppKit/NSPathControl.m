#import <AppKit/NSPathControl.h>

#import "AppKit/NSRaise.h"

// A path control asks its delegate for the contents of each component, so
// without this the control shows nothing.
@interface NSPathControl ()
{
    id<NSPathControlDelegate> _delegate;
}
@end

@implementation NSPathControl

- (BOOL) isFlipped {
    return YES;
}

- (NSPathStyle) pathStyle; {
    NSPathCell *cell = [self cell];
    return [cell pathStyle];
}

- (void) setPathStyle: (NSPathStyle) style; {
    NSPathCell *cell = [self cell];
    [cell setPathStyle: style];
}

- (NSColor *) backgroundColor; {
    NSPathCell *cell = [self cell];
    return [cell backgroundColor];
}

- (void) setBackgroundColor: (NSColor *) color; {
    NSPathCell *cell = [self cell];
    [cell setBackgroundColor: color];
}

- (NSPathComponentCell *) clickedPathComponentCell {
    NSPathCell *cell = [self cell];
    return [cell clickedPathComponentCell];
}

- (NSArray *) pathComponentCells; {
    NSPathCell *cell = [self cell];
    return [cell pathComponentCells];
}

- (void) setPathComponentCells: (NSArray *) cells; {
    NSPathCell *cell = [self cell];
    [cell setPathComponentCells: cells];
}

- (SEL) doubleAction; {
    NSPathCell *cell = [self cell];
    return [cell doubleAction];
}

- (void) setDoubleAction: (SEL) action; {
    NSPathCell *cell = [self cell];
    [cell setDoubleAction: action];
}

- (NSURL *) URL; {
    NSPathCell *cell = [self cell];
    return [cell URL];
}
- (void) setURL: (NSURL *) url; {
    NSPathCell *cell = [self cell];
    [cell setURL: url];
}

- (id<NSPathControlDelegate>) delegate; {
    return _delegate;
}

- (void) setDelegate: (id<NSPathControlDelegate>) delegate; {
    if (_delegate == delegate)
        return;
    [_delegate release];
    _delegate = [delegate retain];
}

- (void) setDraggingSourceOperationMask: (NSDragOperation) mask
                               forLocal: (BOOL) isLocal;
{
    NSUnimplementedMethod();
}

- (NSMenu *) menu; {
    NSPathCell *cell = [self cell];
    //	return [cell menu];
    return nil;
}

- (void) setMenu: (NSMenu *) menu; {
    NSPathCell *cell = [self cell];
    //	[cell setMenu: menu];
}

+ (void) initialize; {
    if (self == [NSPathControl class]) {
        [self setCellClass: [NSPathCell class]];
    }
}

@end
