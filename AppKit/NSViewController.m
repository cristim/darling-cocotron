#import <AppKit/NSNib.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSStoryboard-Private.h>
#import <AppKit/NSViewController.h>

@implementation NSViewController

@synthesize identifier = _identifier;

- initWithNibName: (NSString *) name bundle: (NSBundle *) bundle {
    _nibName = [name copy];
    _nibBundle = [bundle retain];
    return self;
}

- initWithCoder: (NSCoder *) coder {
    if ([coder allowsKeyedCoding]) {
        _nibName = [[coder decodeObjectForKey: @"NSNibName"] copy];
        _title = [[coder decodeObjectForKey: @"NSTitle"] copy];
        NSString *bundleIdentifier =
                [coder decodeObjectForKey: @"NSNibBundleIdentifier"];
        if (bundleIdentifier != nil)
            _nibBundle = [NSBundle bundleWithIdentifier: bundleIdentifier];
        _storyboard = [[NSStoryboard _instantiatingStoryboard] retain];
    }

    return self;
}

- (void) dealloc {
    [_identifier release];
    [_storyboard release];

    [super dealloc];
}

- (NSString *) nibName {
    return _nibName;
}

- (NSBundle *) nibBundle {
    return _nibBundle;
}

- (NSStoryboard *) storyboard {
    return _storyboard;
}

- (NSView *) view {
    if (_view == nil)
        [self loadView];

    return _view;
}

- (NSString *) title {
    return _title;
}

- representedObject {
    return _representedObject;
}

- (void) setRepresentedObject: object {
    object = [object retain];
    [_representedObject release];
    _representedObject = object;
}

- (void) setTitle: (NSString *) value {
    value = [value retain];
    [_title release];
    _title = value;
}

- (void) setView: (NSView *) value {
    value = [value retain];
    [_view release];
    _view = value;
}

- (void) loadView {
    NSString *name = [self nibName];
    NSBundle *bundle = [self nibBundle];

    if (bundle == nil)
        bundle = [NSBundle mainBundle];

    // Since OS X 10.10 a nil nibName means the nib named after the class.
    BOOL named = name != nil;
    if (!named)
        name = NSStringFromClass([self class]);

    // A storyboard scene's view is archived in its own nib inside the storyboard.
    NSString *path = [_storyboard _pathForNibNamed: name];
    if (path == nil)
        path = [bundle pathForResource: name ofType: @"nib"];
    if (path == nil && !named)
        [NSException raise: NSInvalidArgumentException
                    format: @"-[%@ %@] nibName is nil and %@ has no nib named %@",
                            [self class], NSStringFromSelector(_cmd), bundle, name];

    NSDictionary *nameTable = [NSDictionary dictionaryWithObject: self
                                                          forKey: NSNibOwner];

    if (path == nil)
        NSLog(@"NSViewController unable to find nib named %@, bundle=%@", name,
              bundle);

    [bundle loadNibFile: path externalNameTable: nameTable withZone: NULL];
}

- (void) discardEditing {
    NSUnimplementedMethod();
}

- (BOOL) commitEditing {
    NSUnimplementedMethod();
    return NO;
}

- (void) commitEditingWithDelegate: delegate
                 didCommitSelector: (SEL) didCommitSelector
                       contextInfo: (void *) contextInfo
{
    NSUnimplementedMethod();
}

@end
