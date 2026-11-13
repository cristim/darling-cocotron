#import <AppKit/NSSharingServicePickerToolbarItem.h>
#import <AppKit/NSSharingService.h>
#import <AppKit/NSView.h>

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

// Private, required by Mac Catalyst frameworks and not documented. The item's
// action: it asks the delegate for the items to share and shows the sharing
// picker for them next to the item's view. Cocotron's picker has no services,
// so nothing appears, as with every NSSharingServicePicker here.
- (void) share: (id) sender {
    if (![_delegate respondsToSelector: @selector(itemsForSharingServicePickerToolbarItem:)])
        return;

    NSArray *items = [_delegate itemsForSharingServicePickerToolbarItem: self];
    NSView *view = [self view];
    if (view == nil)
        return;

    NSSharingServicePicker *picker = [[NSSharingServicePicker alloc] initWithItems: items];
    [picker showRelativeToRect: [view bounds] ofView: view preferredEdge: NSMinYEdge];
    [picker release];
}

@end
