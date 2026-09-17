#import <AppKit/NSTitlebarAccessoryViewController.h>

@implementation NSTitlebarAccessoryViewController

@synthesize layoutAttribute = _layoutAttribute;

- (instancetype) init {
    return [self initWithNibName: nil bundle: nil];
}

- (instancetype) initWithNibName: (NSString *) name bundle: (NSBundle *) bundle {
    if ((self = [super initWithNibName: name bundle: bundle]))
        _layoutAttribute = NSLayoutAttributeBottom;
    return self;
}

// The archived layout attribute isn't decoded: the default applies.
- (instancetype) initWithCoder: (NSCoder *) coder {
    if ((self = [super initWithCoder: coder]))
        _layoutAttribute = NSLayoutAttributeBottom;
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
