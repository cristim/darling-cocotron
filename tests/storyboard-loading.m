// Standalone AppKit regression: loads the compiled storyboard written by storyboard-loading.py.
// usage: storyboard-loading DIRECTORY_CONTAINING_Fixture.storyboardc
#import <AppKit/AppKit.h>
#include <stdio.h>

@interface FixtureViewController : NSViewController
@end
@implementation FixtureViewController
@end

@interface FixtureView : NSView {
    id _upstream;
}
@property (retain) id upstream;
@end
@implementation FixtureView
@synthesize upstream = _upstream;
- (void)dealloc {
    [_upstream release];
    [super dealloc];
}
@end

@interface FixtureWindowController : NSWindowController {
    NSViewController *_fixtureContentViewController;
}
@end
@implementation FixtureWindowController
- (NSViewController *)contentViewController {
    return _fixtureContentViewController;
}
- (void)setContentViewController:(NSViewController *)controller {
    [controller retain];
    [_fixtureContentViewController release];
    _fixtureContentViewController = controller;
}
- (void)dealloc {
    [_fixtureContentViewController release];
    [super dealloc];
}
@end

static int checks, failures;

static void expect(BOOL ok, const char *what) {
    checks++;
    if (!ok) {
        printf("FAIL %s\n", what);
        failures++;
    }
}

static NSString *raisedName(void (^block)(void)) {
    @try {
        block();
    } @catch (NSException *exception) {
        return [exception name];
    }
    return nil;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 2) {
            puts("usage: storyboard-loading DIRECTORY");
            return 2;
        }
        NSBundle *bundle = [NSBundle bundleWithPath: [NSString stringWithUTF8String: argv[1]]];
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName: @"Fixture" bundle: bundle];
        expect(storyboard != nil, "storyboardWithName:bundle: finds Fixture.storyboardc");
        expect([NSStoryboard mainStoryboard] == nil, "no main storyboard without NSMainStoryboardFile");
        expect([raisedName(^{ [NSStoryboard storyboardWithName: @"Missing" bundle: bundle]; })
                       isEqual: NSInvalidArgumentException],
               "a missing storyboard raises NSInvalidArgumentException");

        id initial = [storyboard instantiateInitialController];
        expect([initial isMemberOfClass: [NSWindowController class]], "initial controller is the window controller");
        expect([initial storyboard] == storyboard, "window controller records its storyboard");

        FixtureViewController *detail = [storyboard instantiateControllerWithIdentifier: @"Detail"];
        expect([detail isMemberOfClass: [FixtureViewController class]], "Detail decodes as its archived class");
        expect([[detail title] isEqual: @"Detail"], "Detail keeps its archived title");
        expect([detail storyboard] == storyboard, "view controller records its storyboard");
        expect([detail view] != nil && NSEqualSizes([[detail view] frame].size, NSMakeSize(240, 120)),
               "Detail loads its view from the nib inside the storyboard");
        expect([(FixtureView *)[detail view] upstream] == detail,
               "a separate storyboard view nib resolves an upstream scene placeholder");
        expect([storyboard instantiateControllerWithIdentifier: @"Detail"] != detail,
               "each instantiation creates a new controller");

        FixtureViewController *scene = [storyboard instantiateControllerWithIdentifier: @"Placeholder"];
        expect([[scene title] isEqual: @"Placeholder"], "the scene with an external placeholder loads");
        expect([scene representedObject] == storyboard, "the scene's external placeholder is its storyboard");

        expect([raisedName(^{ [storyboard instantiateControllerWithIdentifier: @"Nope"]; })
                       isEqual: NSInvalidArgumentException],
               "an unknown identifier raises NSInvalidArgumentException");
        expect([raisedName(^{ [storyboard instantiateControllerWithIdentifier: @"Unbuilt"]; })
                       isEqual: NSInternalInconsistencyException],
               "a scene whose nib is missing raises");
        expect([raisedName(^{ [storyboard instantiateControllerWithIdentifier: @"Ambiguous"]; })
                       isEqual: NSInternalInconsistencyException],
               "a scene with two top-level controllers raises");

        NSViewController *parent = [storyboard instantiateControllerWithIdentifier: @"Contained"];
        expect([parent isKindOfClass: [FixtureViewController class]],
               "a scene returns its parent view controller");
        expect([[parent childViewControllers] count] == 1 &&
               [[[parent childViewControllers] objectAtIndex: 0] parentViewController] == parent,
               "a top-level child is attached to its scene controller");

        FixtureWindowController *windowScene =
                [storyboard instantiateControllerWithIdentifier: @"WindowWithContent"];
        expect([windowScene isKindOfClass: [FixtureWindowController class]],
               "a scene returns its window controller");
        expect([[windowScene contentViewController] isKindOfClass: [FixtureViewController class]],
               "a top-level content view controller belongs to its window controller");

        id unattached = [storyboard instantiateControllerWithIdentifier: @"WindowWithUnattached"];
        expect([unattached isKindOfClass: [FixtureWindowController class]],
               "the sole window controller is the scene entry point before its content is attached");
        expect([raisedName(^{ [storyboard instantiateControllerWithIdentifier: @"TwoWindows"]; })
                       isEqual: NSInternalInconsistencyException],
               "a scene with two window controllers raises");

        printf("storyboard loading checks=%d failures=%d\n", checks, failures);
        return failures != 0;
    }
}
