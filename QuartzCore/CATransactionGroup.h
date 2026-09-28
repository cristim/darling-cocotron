#import <Foundation/NSObject.h>

@class NSMutableDictionary;

@interface CATransactionGroup : NSObject {
    NSMutableDictionary *_values;
    // NO for the implicit group opened by reading a transaction property, YES for
    // the one +begin pushes. Only the latter makes property changes animated.
    BOOL _explicitlyBegan;
}

- valueForKey: (NSString *) key;
- (void) setValue: value forKey: (NSString *) key;

- (BOOL) isExplicitlyBegan;
- (void) setExplicitlyBegan: (BOOL) value;

@end
