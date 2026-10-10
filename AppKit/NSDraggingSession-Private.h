#import <AppKit/NSDraggingSession.h>

@interface NSDraggingSession (Private)
- (instancetype) _initWithPasteboard: (NSPasteboard *) pasteboard;
- (void) _setDraggingLocation: (NSPoint) location;
@end

// Adapts a session-style NSDraggingSource to the legacy callbacks that the
// backend dragging managers call.
@interface _NSDraggingSourceBridge : NSObject
- (instancetype) initWithSession: (NSDraggingSession *) session source: (id) source;
@property(readonly) BOOL began;
// The caller's source, which draggingSource must keep returning.
- (id) _originalDraggingSource;
@end
