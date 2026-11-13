#import <AppKit/NSSharingServicePickerToolbarItem.h>

@implementation NSSharingServicePickerToolbarItem

@synthesize delegate = _delegate;
@synthesize activityItemsConfiguration = _activityItemsConfiguration;

- (void) dealloc {
    [_activityItemsConfiguration release];
    [super dealloc];
}

// NSToolbarItem copies with NSCopyObject, which shares the ivar without a retain.
- (id) copyWithZone: (NSZone *) zone {
    NSSharingServicePickerToolbarItem *copy = [super copyWithZone: zone];

    copy->_activityItemsConfiguration = [_activityItemsConfiguration retain];
    return copy;
}

@end
