#import <AppKit/NSViewController.h>
#import <AppKit/NSLayoutConstraint.h>
#import <Foundation/Foundation.h>

@class NSScrollEdgeEffectStyle;

@interface NSTitlebarAccessoryViewController : NSViewController {
    NSLayoutAttribute _layoutAttribute;
    NSScrollEdgeEffectStyle *_preferredScrollEdgeEffectStyle;
}

// Stored only: accessories aren't placed in the title bar.
@property NSLayoutAttribute layoutAttribute;
@property (retain) NSScrollEdgeEffectStyle *preferredScrollEdgeEffectStyle;

@end
