#import <AppKit/NSResponder.h>
#import <AppKit/NSUserInterfaceItemIdentification.h>

@class NSView, NSStoryboard;

@interface NSViewController : NSResponder <NSUserInterfaceItemIdentification> {
    NSString *_nibName;
    NSBundle *_nibBundle;
    id _representedObject;
    NSString *_title;
    NSView *_view;
    NSUserInterfaceItemIdentifier _identifier;
    NSMutableArray *_childViewControllers;
    NSViewController *_parentViewController;
    NSStoryboard *_storyboard;
    NSSize _preferredContentSize;
}

- initWithNibName: (NSString *) name bundle: (NSBundle *) bundle;

- (NSString *) nibName;
- (NSBundle *) nibBundle;

@property (retain, nonnull) NSView *view;
@property(readonly, strong) NSStoryboard *storyboard;
@property NSSize preferredContentSize;
@property(copy) NSArray<__kindof NSViewController *> *childViewControllers;
@property(readonly) NSViewController *parentViewController;

- (void) addChildViewController: (NSViewController *) childViewController;
// Subclasses that track their children override these two; the other child
// methods go through them.
- (void) insertChildViewController: (NSViewController *) childViewController
                           atIndex: (NSInteger) index;
- (void) removeChildViewControllerAtIndex: (NSInteger) index;
- (void) removeFromParentViewController;
- (NSString *) title;
- representedObject;

- (void) setRepresentedObject: object;

- (void) setTitle: (NSString *) value;


- (void) loadView;
// Called once -view has loaded the view with -loadView; does nothing by default.
- (void) viewDidLoad;
@property(readonly, getter=isViewLoaded) BOOL viewLoaded;

- (void) discardEditing;

- (BOOL) commitEditing;
- (void) commitEditingWithDelegate: delegate
                 didCommitSelector: (SEL) didCommitSelector
                       contextInfo: (void *) contextInfo;

@end
