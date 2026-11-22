#import <AppKit/NSViewController.h>
#import <AppKit/NSLayoutConstraint.h>
#import <Foundation/Foundation.h>

@interface NSTitlebarAccessoryViewController : NSViewController {
    NSLayoutAttribute _layoutAttribute;
}

// Stored only: accessories aren't placed in the title bar.
@property NSLayoutAttribute layoutAttribute;

@end
