#import <AppKit/NSSharingService.h>
#import <AppKit/NSToolbarItem.h>

@class NSSharingServicePickerToolbarItem;

@protocol NSSharingServicePickerToolbarItemDelegate <NSSharingServicePickerDelegate>
- (NSArray *) itemsForSharingServicePickerToolbarItem: (NSSharingServicePickerToolbarItem *) pickerToolbarItem;
@end

// A toolbar item that offers sharing for the items its delegate returns.
// Cocotron has no sharing services to pick from, so the item is an ordinary
// toolbar item that keeps its delegate.
@interface NSSharingServicePickerToolbarItem : NSToolbarItem {
    id _delegate;
    id _activityItemsConfiguration;
}

@property (assign) id<NSSharingServicePickerToolbarItemDelegate> delegate;

// Cocotron has no NSUIActivityItemsConfigurationReading, so the configuration is
// kept as an object and not used.
@property (retain) id activityItemsConfiguration;

@end
