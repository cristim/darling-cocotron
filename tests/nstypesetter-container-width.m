/*
 * NSTextContainer width must constrain line layout.
 *
 * Regression: NSTypesetter_concrete seeded its scan rect with a fixed width of
 * 1e7 ("That's what Cocoa is sending") and reset it to 1e7 whenever it advanced
 * to a new line. That removed the width constraint entirely, so every string
 * measured as one line no matter how narrow the text container was. Callers
 * that size text to a proposal - which is what OpenSwiftUI's Text does on every
 * layout pass - then received a width far larger than the space they offered,
 * laid the text out centred on that width, and got a display-list item whose
 * origin was off the left edge of its container.
 *
 * These assertions pin the AppKit contract instead: a finite container width
 * wraps, an unconstrained size does not, and a string that already fits is
 * unaffected.
 *
 * Exit codes: 0 pass, 1 wrapped width still exceeds the container, 2 wrapping
 * did not add a line, 3 unconstrained measurement stopped wrapping, 4 a short
 * string was altered, 5 the private context-taking entry point disagrees.
 */
#import <AppKit/AppKit.h>

/* Private entry point, the one real callers use. The public three-argument
   variant below routes to the same typesetter, so the contract is covered even
   where the private declaration is unavailable. */
@interface NSAttributedString (AZPrivateStringDrawing)
- (NSRect) boundingRectWithSize: (NSSize) size
                        options: (NSStringDrawingOptions) options
                        context: (id) context;
@end

static NSDictionary *MakeAttributes(void) {
    NSFont *font = [NSFont systemFontOfSize: 13];
    if (font == nil) {
        return nil;
    }
    return [NSDictionary dictionaryWithObject: font forKey: NSFontAttributeName];
}

static NSAttributedString *MakeAttributed(NSString *text) {
    NSDictionary *attributes = MakeAttributes();
    if (attributes == nil) {
        return nil;
    }
    return [[[NSAttributedString alloc] initWithString: text
                                            attributes: attributes] autorelease];
}

int main(void) {
    @autoreleasepool {
        NSString *sentence =
            @"This one-time setup authorizes AppZapper 3000 to find and delete "
            @"apps on your Mac when you ask it to.";
        NSDictionary *attributes = MakeAttributes();
        NSString *shortString = @"Hi";
        NSAttributedString *string = MakeAttributed(sentence);
        if (attributes == nil || string == nil) {
            return 4;
        }

        /* Unconstrained: a zero size means "no constraint", so the string must
           come back as a single line at its natural width. */
        NSRect unconstrained = [sentence boundingRectWithSize: NSMakeSize(0, 0)
                                                     options: 0
                                                  attributes: attributes];
        CGFloat naturalWidth = unconstrained.size.width;
        CGFloat lineHeight = unconstrained.size.height;

        /* A finite width must wrap. */
        const CGFloat containerWidth = 200;
        NSRect constrained = [sentence boundingRectWithSize: NSMakeSize(containerWidth, 0)
                                                   options: 0
                                                attributes: attributes];

        if (constrained.size.width <= 0) {
            NSLog(@"constrained measurement is empty (%g x %g), so the width was "
                  @"not honoured as a layout constraint at all",
                  constrained.size.width, constrained.size.height);
            return 1;
        }
        if (constrained.size.width > containerWidth + 0.5) {
            NSLog(@"constrained width %g still exceeds the container width %g",
                  constrained.size.width, containerWidth);
            return 1;
        }
        if (constrained.size.height <= lineHeight + 0.5) {
            NSLog(@"constrained height %g did not grow past the single-line "
                  @"height %g, so the text was not wrapped",
                  constrained.size.height, lineHeight);
            return 2;
        }

        /* A width that comfortably fits the string must leave it on one line
           at its natural width, so the constraint is not applied blindly. */
        NSRect wide = [sentence boundingRectWithSize: NSMakeSize(naturalWidth + 40, 0)
                                            options: 0
                                         attributes: attributes];
        if (fabs(wide.size.width - naturalWidth) > 1.0 ||
            wide.size.height > lineHeight + 0.5) {
            NSLog(@"a container wider than the text changed the result: "
                  @"%g x %g instead of %g x %g",
                  wide.size.width, wide.size.height, naturalWidth, lineHeight);
            return 3;
        }

        /* A string that fits must be untouched by the constraint. */
        NSRect shortConstrained = [shortString boundingRectWithSize: NSMakeSize(containerWidth, 0)
                                                            options: 0
                                                         attributes: attributes];
        NSRect shortUnconstrained = [shortString boundingRectWithSize: NSMakeSize(0, 0)
                                                              options: 0
                                                           attributes: attributes];
        if (fabs(shortConstrained.size.width - shortUnconstrained.size.width) > 0.5 ||
            shortConstrained.size.height > lineHeight + 0.5) {
            NSLog(@"a short string changed under a width constraint: %g x %g "
                  @"instead of %g x %g",
                  shortConstrained.size.width, shortConstrained.size.height,
                  shortUnconstrained.size.width, shortUnconstrained.size.height);
            return 4;
        }

        /* The private context-taking entry point, which is what OpenSwiftUI
           calls, must agree. */
        NSRect privateConstrained = [string boundingRectWithSize: NSMakeSize(containerWidth, 0)
                                                        options: 0
                                                        context: nil];
        if (privateConstrained.size.width > containerWidth + 0.5) {
            NSLog(@"private boundingRectWithSize:options:context: width %g still "
                  @"exceeds the container width %g",
                  privateConstrained.size.width, containerWidth);
            return 5;
        }

        NSLog(@"PASS natural=%.1fx%.1f constrained=%.1fx%.1f short=%.1fx%.1f",
              naturalWidth, lineHeight, constrained.size.width,
              constrained.size.height, shortUnconstrained.size.width,
              shortUnconstrained.size.height);
        return 0;
    }
}
