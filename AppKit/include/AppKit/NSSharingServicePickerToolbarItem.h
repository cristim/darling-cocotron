#import <AppKit/NSToolbarItem.h>

@class NSSharingServicePickerToolbarItem;

@protocol NSSharingServicePickerToolbarItemDelegate <NSObject>
- (NSArray *) itemsForSharingServicePickerToolbarItem: (NSSharingServicePickerToolbarItem *) pickerToolbarItem;
@end

// A toolbar item that offers sharing for the items its delegate returns.
// Cocotron has no sharing services to pick from, so the item is an ordinary
// toolbar item that keeps its delegate.
@interface NSSharingServicePickerToolbarItem : NSToolbarItem {
    id _delegate;
}

@property (assign) id<NSSharingServicePickerToolbarItemDelegate> delegate;

@end
