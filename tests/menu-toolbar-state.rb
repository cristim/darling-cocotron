# Actual subclass implementation with controlled toolbar/menu collaborators.
# This tests state/ownership plumbing, not drawing or menu tracking.
require 'open3'
require 'tmpdir'
sdk=ARGV.fetch(0)
root=File.expand_path('..',__dir__)
source=%w[AppKit/include/AppKit/NSMenuToolbarItem.h AppKit/NSMenuToolbarItem.m].map { |f| File.read("#{root}/#{f}").gsub(/^#import.*\n/,'') }.join("\n")
base=File.read("#{root}/AppKit/NSToolbar.subproj/NSToolbarItem.m")
validation=base[/^- \(void\) validate \{.*?^\}/m] or abort 'missing base validation'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  typedef NSString *NSToolbarItemIdentifier;
  typedef NSInteger NSToolbarSizeMode, NSToolbarDisplayMode;
  #define NSMouseInRect(point, rect, flipped) NSPointInRect(point, rect)
  @interface NSEvent : NSObject { @public NSPoint point; }
  - (NSPoint)locationInWindow;
  @end
  @implementation NSEvent
  - (NSPoint)locationInWindow { return point; }
  @end
  static int fills, strokes;
  static BOOL checkPoints;
  static NSRect drawingBounds;
  static void checkPoint(NSPoint p) {
    if (checkPoints) {
      assert(p.x>=NSMinX(drawingBounds) && p.x<=NSMaxX(drawingBounds));
      assert(p.y>=NSMinY(drawingBounds) && p.y<=NSMaxY(drawingBounds));
    }
  }
  @interface NSColor : NSObject
  + (id)controlTextColor;
  + (id)disabledControlTextColor;
  - (void)set;
  @end
  @implementation NSColor
  + (id)controlTextColor { return [[[self alloc] init] autorelease]; }
  + (id)disabledControlTextColor { return [self controlTextColor]; }
  - (void)set {}
  @end
  @interface NSBezierPath : NSObject
  + (id)bezierPath;
  - (void)moveToPoint:(NSPoint)p;
  - (void)lineToPoint:(NSPoint)p;
  - (void)closePath;
  - (void)fill;
  - (void)stroke;
  @end
  @implementation NSBezierPath
  + (id)bezierPath { return [[[self alloc] init] autorelease]; }
  - (void)moveToPoint:(NSPoint)p { checkPoint(p); }
  - (void)lineToPoint:(NSPoint)p { checkPoint(p); }
  - (void)closePath {}
  - (void)fill { fills++; }
  - (void)stroke { strokes++; }
  @end
  static int menuDeaths;
  @class NSEvent, NSView;
  static id trackedMenu, trackedEvent, trackedView;
  static void (*duringPeek)(void);
  static void (*duringPopup)(void);
  enum { NSLeftMouseUpMask=4, NSLeftMouseDraggedMask=8 };
  #define NSEventTrackingRunLoopMode @"tracking"
  @interface ProbeApplication : NSObject { @public id pending; BOOL dequeued; NSUInteger mask; NSString *mode; }
  - (id)nextEventMatchingMask:(NSUInteger)value untilDate:(NSDate*)date inMode:(NSString*)runMode dequeue:(BOOL)remove;
  - (id)targetForAction:(SEL)action to:(id)target from:(id)sender;
  @end
  @implementation ProbeApplication
  - (id)targetForAction:(SEL)action to:(id)target from:(id)sender { return target; }
  - (id)nextEventMatchingMask:(NSUInteger)value untilDate:(NSDate*)date inMode:(NSString*)runMode dequeue:(BOOL)remove {
    assert([date timeIntervalSinceNow]>0);
    mask=value; mode=runMode; dequeued=remove;
    if (duringPeek) duringPeek();
    return pending;
  }
  @end
  static ProbeApplication *NSApp;
  @interface NSMenu : NSObject
  - (id)initWithTitle:(NSString*)title;
  + (void)popUpContextMenu:(id)menu withEvent:(id)event forView:(id)view;
  @end
  @implementation NSMenu
  - (id)initWithTitle:(NSString*)title { return [super init]; }
  + (void)popUpContextMenu:(id)menu withEvent:(id)event forView:(id)view {
    trackedMenu=menu; trackedEvent=event; trackedView=view;
    if (duringPopup) duringPopup();
  }
  - (void)dealloc { menuDeaths++; [super dealloc]; }
  @end
  @interface NSMenuItem : NSObject { @public NSMenu *submenu; }
  - (void)setSubmenu:(NSMenu*)value;
  @end
  @implementation NSMenuItem
  - (void)setSubmenu:(NSMenu*)value { [value retain]; [submenu release]; submenu=value; }
  - (void)dealloc { [submenu release]; [super dealloc]; }
  @end
  @interface NSToolbarItem : NSObject {
    @public NSMenuItem *_menuFormRepresentation; int redraws; SEL action; BOOL disabled; id target;
  }
  - (id)initWithItemIdentifier:(NSString*)identifier;
  - (NSMenuItem*)menuFormRepresentation;
  - (void)_didChange;
  - (SEL)action;
  - (BOOL)isEnabled;
  - (void)setEnabled:(BOOL)enabled;
  - (id)target;
  - (id)view;
  - (void)validate;
  - (BOOL)validateToolbarItem:(id)item;
  - (BOOL)validateUserInterfaceItem:(id)item;
  - (void)drawInRect:(NSRect)bounds highlighted:(BOOL)highlighted;
  - (NSSize)sizeForSizeMode:(NSToolbarSizeMode)s displayMode:(NSToolbarDisplayMode)d minSize:(NSSize)a maxSize:(NSSize)b;
  @end
  @implementation NSToolbarItem
  - (id)initWithItemIdentifier:(NSString*)identifier { return [super init]; }
  - (NSMenuItem*)menuFormRepresentation {
    if (!_menuFormRepresentation) _menuFormRepresentation=[NSMenuItem new];
    return _menuFormRepresentation;
  }
  - (void)_didChange { redraws++; }
  - (SEL)action { return action; }
  - (BOOL)isEnabled { return !disabled; }
  - (void)setEnabled:(BOOL)enabled { disabled=!enabled; }
  - (id)target { return target; }
  - (id)view { return nil; }
  - (BOOL)validateToolbarItem:(id)item { return YES; }
  - (BOOL)validateUserInterfaceItem:(id)item { return YES; }
  BASE_VALIDATION
  - (void)drawInRect:(NSRect)bounds highlighted:(BOOL)highlighted {}
  - (NSSize)sizeForSizeMode:(NSToolbarSizeMode)s displayMode:(NSToolbarDisplayMode)d minSize:(NSSize)a maxSize:(NSSize)b {
    CGFloat width=MAX(40,a.width);
    if (b.width>0) width=MIN(width,b.width);
    return NSMakeSize(width,32);
  }
  - (void)dealloc { [_menuFormRepresentation release]; [super dealloc]; }
  @end
  @interface NSToolbarItemView : NSObject { @public id owner, window; }
  - (id)toolbarItem;
  - (id)window;
  - (NSRect)bounds;
  - (NSPoint)convertPoint:(NSPoint)p fromView:(id)view;
  - (BOOL)isFlipped;
  @end
  @implementation NSToolbarItemView
  - (id)toolbarItem { return owner; }
  - (id)window { return window; }
  - (NSRect)bounds { return NSMakeRect(0,0,52,32); }
  - (NSPoint)convertPoint:(NSPoint)p fromView:(id)view { return p; }
  - (BOOL)isFlipped { return NO; }
  @end
  SOURCE
  static NSMenuToolbarItem *activeItem;
  static NSToolbarItemView *activeView;
  static void replaceItem(void) { activeView->owner=nil; }
  static void detachView(void) { activeView->window=nil; }
  static void reenterAndDisable(void) {
    assert([activeItem _trackMenuWithEvent:nil inView:nil]);
    assert(trackedMenu==nil);
    activeItem->disabled=YES;
  }
  static void throwDuringCallback(void) {
    [NSException raise:@"ProbeTrackingException" format:@"controlled callback failure"];
  }
  static void checkExceptionCleanup(NSMenuToolbarItem *item, id event, id view, BOOL popup) {
    // Read the atomic getter before measuring, since it may autorelease a retain.
    NSMenu *menu=[item menu];
    NSUInteger itemCount=[item retainCount], eventCount=[event retainCount];
    NSUInteger viewCount=[view retainCount], menuCount=[menu retainCount];
    duringPeek=popup ? NULL : throwDuringCallback;
    duringPopup=popup ? throwDuringCallback : NULL;
    BOOL caught=NO;
    @try {
      [item _trackMenuWithEvent:event inView:view];
    } @catch (NSException *exception) {
      assert([[exception name] isEqual:@"ProbeTrackingException"]);
      caught=YES;
    }
    duringPeek=NULL; duringPopup=NULL;
    assert(caught);
    assert([item retainCount]==itemCount && [event retainCount]==eventCount);
    assert([view retainCount]==viewCount && [menu retainCount]==menuCount);
    // An exception must not leave the transient tracking guard latched.
    trackedMenu=nil;
    assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==menu);
  }
  int main(void) {
    @autoreleasepool {
      NSMenuToolbarItem *item=[[NSMenuToolbarItem alloc] initWithItemIdentifier:@"fonts"];
      assert([item menu]!=nil && [item showsIndicator]);
      assert(item->_menuFormRepresentation==nil);
      NSMenuItem *representation=[item menuFormRepresentation];
      assert(representation->submenu==[item menu]);
      NSMenu *replacement=[[NSMenu alloc] initWithTitle:@"new"];
      [item setMenu:replacement];
      assert(representation->submenu==replacement && item->redraws==1);
      [item setMenu:replacement]; assert(item->redraws==1);
      [replacement release];
      [item setShowsIndicator:NO]; assert(item->redraws==2 && ![item showsIndicator]);
      [item setShowsIndicator:NO]; assert(item->redraws==2);
      [item setMenu:nil]; assert([item menu]!=nil && representation->submenu==[item menu]);
      NSEvent *event=[NSEvent new]; event->point=NSMakePoint(5,10);
      id window=[NSObject new];
      NSToolbarItemView *view=[NSToolbarItemView new];
      view->owner=item; view->window=window; activeView=view;
      assert([item _trackMenuWithEvent:event inView:view]);
      assert(trackedMenu==[item menu] && trackedEvent==event && trackedView==view);
      trackedMenu=nil; item->action=@selector(description);
      NSApp=[ProbeApplication new]; NSApp->pending=event;
      assert(![item _trackMenuWithEvent:event inView:view] && trackedMenu==nil);
      assert(!NSApp->dequeued && NSApp->mask==(NSLeftMouseUpMask|NSLeftMouseDraggedMask));
      assert([NSApp->mode isEqual:NSEventTrackingRunLoopMode]);
      NSApp->pending=nil;
      assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==[item menu]);
      trackedMenu=nil; activeItem=item; duringPeek=reenterAndDisable;
      assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==nil);
      duringPeek=NULL; item->disabled=NO;
      assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==[item menu]);
      checkExceptionCleanup(item,event,view,NO);
      checkExceptionCleanup(item,event,view,YES);
      // Cancellation must cover both the timeout/menu and quick/action paths.
      for (int quick=0; quick<2; quick++) {
        NSApp->pending=quick ? event : nil;
        trackedMenu=nil; duringPeek=replaceItem;
        assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==nil);
        view->owner=item; duringPeek=detachView;
        assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==nil);
        view->window=window;
      }
      duringPeek=NULL;
      [item setShowsIndicator:YES];
      NSRect indicator=[item _menuIndicatorRectForBounds:[view bounds]];
      assert(NSEqualRects(indicator,NSMakeRect(40,0,12,32)));
      assert([item sizeForSizeMode:0 displayMode:0 minSize:NSZeroSize maxSize:NSZeroSize].width==52);
      [item drawInRect:[view bounds] highlighted:NO];
      assert(fills==1 && strokes==1);
      // A quick click in the visible segment bypasses the hold wait entirely.
      duringPeek=throwDuringCallback; event->point=NSMakePoint(46,10);
      trackedMenu=nil;
      assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==[item menu]);
      duringPeek=NULL;
      [item setShowsIndicator:NO]; trackedMenu=nil;
      assert(![item _trackMenuWithEvent:event inView:view] && trackedMenu==nil);
      [item drawInRect:[view bounds] highlighted:NO];
      assert(fills==1 && strokes==1);
      item->action=NULL;
      [item setShowsIndicator:YES];
      assert([item sizeForSizeMode:0 displayMode:0 minSize:NSMakeSize(60,0) maxSize:NSZeroSize].width==60);
      assert([item sizeForSizeMode:0 displayMode:0 minSize:NSZeroSize maxSize:NSMakeSize(48,0)].width==48);
      assert([item sizeForSizeMode:0 displayMode:0 minSize:NSZeroSize maxSize:NSMakeSize(4,0)].width==4);
      drawingBounds=NSMakeRect(10,20,4,1); checkPoints=YES;
      [item drawInRect:drawingBounds highlighted:NO];
      assert(fills==2 && strokes==1); // decorative menu-only indicator
      item->action=@selector(description);
      [item drawInRect:drawingBounds highlighted:NO];
      assert(fills==3 && strokes==2);
      [item drawInRect:NSZeroRect highlighted:NO];
      assert(fills==3 && strokes==2);
      checkPoints=NO; item->action=NULL;
      [item validate]; assert([item isEnabled]);
      [item setEnabled:NO]; [item validate]; assert(![item isEnabled]);
      [item setEnabled:YES]; item->action=@selector(description);
      [item validate]; assert(![item isEnabled]);
      item->target=event;
      [item validate]; assert([item isEnabled]);
      // The unmodified superclass disables the identical menu-only setup.
      NSToolbarItem *baseItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"baseline"];
      [baseItem validate]; assert(![baseItem isEnabled]); [baseItem release];
      [NSApp release]; NSApp=nil;
      [event release]; [view release]; [window release];
      [item release];
    }
    assert(menuDeaths==3);
    puts("PASS: menu state, representation sync, quick/held gestures, reentry, disabled state, exception cleanup, ownership after pool drain");
  }
OBJC
program.sub!('SOURCE') { source }
program.sub!('BASE_VALIDATION') { validation }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('menu-toolbar-state') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort log unless status.success?
  abort 'test failed' unless system(output,rlimit_core:0)
end
