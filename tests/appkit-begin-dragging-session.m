#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <unistd.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

// In-memory drag pasteboard so no display connection is needed.
@interface FakePasteboard : NSPasteboard
@property(retain) NSMutableDictionary *items;
@end

@implementation FakePasteboard
- (NSArray *)types { return [self.items allKeys]; }
- (NSData *)dataForType:(NSPasteboardType)type { return self.items[type]; }
- (NSInteger)clearContents { self.items = [NSMutableDictionary dictionary]; return 1; }
- (BOOL)setData:(NSData *)data forType:(NSPasteboardType)type
{
    if (self.items == nil)
        self.items = [NSMutableDictionary dictionary];
    self.items[type] = data;
    return YES;
}
@end

static FakePasteboard *dragBoard;
static id (*originalPasteboardWithName)(id, SEL, NSString *);
static id fakePasteboardWithName(id self, SEL _cmd, NSString *name) { return dragBoard; }

static NSMutableArray *events;
static NSDragOperation mask;
static BOOL beginDrag = YES;

// Stands in for the backend: records the legacy call and drives the callbacks
// in the order a backend does (mask query, began, ended).
@interface SourceView : NSView
@property(retain) NSImage *seenImage;
@property NSPoint seenLocation;
@property(retain) NSPasteboard *seenBoard;
@end

@implementation SourceView
- (void)dragImage:(NSImage *)image at:(NSPoint)location offset:(NSSize)offset event:(NSEvent *)event
       pasteboard:(NSPasteboard *)pasteboard source:(id)source slideBack:(BOOL)slideBack
{
    self.seenImage = image;
    self.seenLocation = location;
    self.seenBoard = pasteboard;
    mask = [source draggingSourceOperationMaskForLocal:NO];
    if (!beginDrag)
        return;
    [source draggedImage:image beganAt:NSMakePoint(3, 4)];
    [source draggedImage:image endedAt:NSMakePoint(5, 6) operation:NSDragOperationCopy];
}
@end

@interface NewSource : NSObject <NSDraggingSource>
@end
@implementation NewSource
- (NSDragOperation)draggingSession:(NSDraggingSession *)s sourceOperationMaskForDraggingContext:(NSDraggingContext)c
{
    [events addObject:[NSString stringWithFormat:@"mask%ld", (long)c]];
    return NSDragOperationMove;
}
- (void)draggingSession:(NSDraggingSession *)s willBeginAtPoint:(NSPoint)p
{
    [events addObject:[NSString stringWithFormat:@"will %g,%g loc %g,%g", p.x, p.y, s.draggingLocation.x, s.draggingLocation.y]];
}
- (void)draggingSession:(NSDraggingSession *)s endedAtPoint:(NSPoint)p operation:(NSDragOperation)op
{
    [events addObject:[NSString stringWithFormat:@"end %g,%g op%lu", p.x, p.y, (unsigned long)op]];
}
@end

// Legacy-only: does not adopt the protocol, whose session mask method is required.
@interface OldSource : NSObject
@end
@implementation OldSource
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local { [events addObject:@"oldmask"]; return NSDragOperationLink; }
- (void)draggedImage:(NSImage *)i beganAt:(NSPoint)p { [events addObject:@"oldbegan"]; }
- (void)draggedImage:(NSImage *)i endedAt:(NSPoint)p operation:(NSDragOperation)op { [events addObject:@"oldend"]; }
@end

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        dragBoard = [[FakePasteboard alloc] init];
        Method m = class_getClassMethod([NSPasteboard class], @selector(pasteboardWithName:));
        originalPasteboardWithName = (void *)method_setImplementation(m, (IMP)fakePasteboardWithName);

        events = [NSMutableArray array];
        SourceView *view = [[[SourceView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)] autorelease];
        NSEvent *event = [NSEvent mouseEventWithType:NSLeftMouseDragged location:NSMakePoint(1, 1)
                                       modifierFlags:0 timestamp:0 windowNumber:0 context:nil
                                         eventNumber:0 clickCount:1 pressure:1];

        NSDraggingItem *item = [[[NSDraggingItem alloc] initWithPasteboardWriter:(id)@"hello"] autorelease];
        expect([item item] != nil, @"item kept");
        expect([item imageComponents] == nil, @"no provider, no components");
        NSImage *icon = [[[NSImage alloc] initWithSize:NSMakeSize(32, 24)] autorelease];
        [item setDraggingFrame:NSMakeRect(7, 8, 32, 24) contents:icon];
        expect([[item imageComponents] count] == 1, @"setDraggingFrame:contents: makes one component");
        expect([[[item imageComponents] firstObject] contents] == icon, @"component contents");
        expect([[NSDraggingItem alloc] initWithPasteboardWriter:nil] == nil, @"nil writer gives nil, no raise");

        NSDraggingSession *session = [view beginDraggingSessionWithItems:@[ item ] event:event source:[[NewSource new] autorelease]];
        expect(session != nil, @"session returned");
        expect([session draggingPasteboard] == dragBoard, @"session pasteboard");
        expect([session animatesToStartingPositionsOnCancelOrFail], @"animates by default");
        expect([[dragBoard.items objectForKey:NSStringPboardType] isEqual:[@"hello" dataUsingEncoding:NSUTF8StringEncoding]], @"item written to drag pasteboard");
        expect(view.seenImage == icon && NSEqualPoints(view.seenLocation, NSMakePoint(7, 8)), @"image and location from the first item");
        expect(mask == NSDragOperationMove, @"session mask used");
        NSArray *expected = @[ @"mask0", @"will 3,4 loc 3,4", @"end 5,6 op1" ];
        expect([events isEqual:expected], [NSString stringWithFormat:@"new-source order: %@", events]);

        [events removeAllObjects];
        session = [view beginDraggingSessionWithItems:@[ item ] event:event source:(id)[[OldSource new] autorelease]];
        expect(session != nil && mask == NSDragOperationLink, @"legacy mask kept");
        expect([events isEqual:(@[ @"oldmask", @"oldbegan", @"oldend" ])], [NSString stringWithFormat:@"old-source order: %@", events]);

        NSDraggingItem *bare = [[[NSDraggingItem alloc] initWithPasteboardWriter:(id)@"zero"] autorelease];
        [view beginDraggingSessionWithItems:@[ bare ] event:event source:(id)[[OldSource new] autorelease]];
        expect(view.seenImage != nil && NSEqualSizes([view.seenImage size], NSZeroSize), @"0x0 image for a frameless item");

        expect([view beginDraggingSessionWithItems:@[] event:event source:[[NewSource new] autorelease]] == nil, @"empty items");
        expect([view beginDraggingSessionWithItems:@[ item ] event:nil source:[[NewSource new] autorelease]] == nil, @"nil event");
        expect([view beginDraggingSessionWithItems:@[ @"not an item" ] event:event source:[[NewSource new] autorelease]] == nil, @"non-item");
        // g21 writeObjects: refuses NSPasteboardItem writers and same-type collisions.
        fflush(stderr);
        NSString *logPath = [NSString stringWithFormat:@"%@/g24-begin-session-%d.log", NSTemporaryDirectory(), getpid()];
        int savedErr = dup(2);
        freopen([logPath fileSystemRepresentation], "w", stderr);
        NSDraggingItem *pbItem = [[[NSDraggingItem alloc] initWithPasteboardWriter:(id)[[[NSPasteboardItem alloc] init] autorelease]] autorelease];
        NSDraggingItem *second = [[[NSDraggingItem alloc] initWithPasteboardWriter:(id)@"world"] autorelease];
        BOOL pbNil = [view beginDraggingSessionWithItems:@[ pbItem ] event:event source:[[NewSource new] autorelease]] == nil;
        BOOL twoNil = [view beginDraggingSessionWithItems:@[ item, second ] event:event source:[[NewSource new] autorelease]] == nil;
        fflush(stderr);
        dup2(savedErr, 2);
        close(savedErr);
        NSString *logged = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:NULL];
        expect(pbNil && twoNil, @"NSPasteboardItem writer and two same-type items return nil");
        expect([logged rangeOfString:@"could not take the items"].location != NSNotFound, @"refusal is logged");
        [[NSFileManager defaultManager] removeItemAtPath:logPath error:NULL];
        beginDrag = NO;
        [events removeAllObjects];
        expect([view beginDraggingSessionWithItems:@[ item ] event:event source:[[NewSource new] autorelease]] == nil, @"drag that never begins");
        expect([events count] == 1, @"no callbacks beyond the mask query when refused");
        printf("PASS: beginDraggingSessionWithItems\n");
    }
    return 0;
}
