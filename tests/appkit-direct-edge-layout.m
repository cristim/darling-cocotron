#import <AppKit/AppKit.h>
#include <stdio.h>

static NSLayoutConstraint *edge(NSView *first, NSLayoutAttribute firstAttribute,
                                NSView *second, NSLayoutAttribute secondAttribute) {
    return [NSLayoutConstraint constraintWithItem: first
                                        attribute: firstAttribute
                                        relatedBy: NSLayoutRelationEqual
                                           toItem: second
                                        attribute: secondAttribute
                                       multiplier: 1
                                         constant: 0];
}

int main(void) {
    @autoreleasepool {
        NSView *content = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 700, 650)] autorelease];
        NSView *toolbar = [[[NSView alloc] initWithFrame: NSMakeRect(-1, -1, 702, 30)] autorelease];
        NSView *editor = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)] autorelease];
        [content addSubview: toolbar];
        [content addSubview: editor];
        [content addConstraints: @[
            edge(editor, NSLayoutAttributeLeft, content, NSLayoutAttributeLeft),
            edge(content, NSLayoutAttributeRight, editor, NSLayoutAttributeRight),
        ]];
        [content addConstraints: @[
            edge(editor, NSLayoutAttributeTop, content, NSLayoutAttributeTop),
            edge(toolbar, NSLayoutAttributeTop, editor, NSLayoutAttributeBottom),
        ]];
        NSRect actual = [editor frame];
        if (!NSEqualRects(actual, NSMakeRect(0, 29, 700, 621))) {
            fprintf(stderr, "unexpected frame: %.0f %.0f %.0f %.0f\n",
                    actual.origin.x, actual.origin.y,
                    actual.size.width, actual.size.height);
            return 1;
        }
        printf("direct edge layout PASS: %.0f %.0f %.0f %.0f\n",
               actual.origin.x, actual.origin.y,
               actual.size.width, actual.size.height);
        return 0;
    }
}
