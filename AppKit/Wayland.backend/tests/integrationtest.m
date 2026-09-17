#import <AppKit/AppKit.h>
#import <OpenGL/gl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// Combined input/DnD/EGL fixture. Use only an isolated native compositor.
static int failures, began, ended, attempts, draws[2], drawsAtStart[2];
@interface NSObject (CombinedPlatformWindow)
- (id)platformWindow;
- (BOOL)isMapped;
@end
static id sourceView;
static NSWindow *sourceWindow;
static NSString *mode;
static void combinedCheck(BOOL pass,const char *name){if(!pass)failures++;printf("CHECK %s %s\n",pass?"PASS":"FAIL",name);fflush(stdout);}
@interface GLContent : NSOpenGLView
@end
@implementation GLContent
- (void)drawRect:(NSRect)rect {
    [[self openGLContext]makeCurrentContext];glClearColor(1,0,1,1);glClear(GL_COLOR_BUFFER_BIT);
    unsigned char pixel[4]={0};glReadPixels(5,5,1,1,GL_RGBA,GL_UNSIGNED_BYTE,pixel);
    if(pixel[0]!=255 || pixel[1]!=0 || pixel[2]!=255 || pixel[3]!=255)failures++;
    draws[[[[self window]title]isEqual:@"Combined source"]?0:1]++;[[self openGLContext]flushBuffer];
}
- (void)tick:(id)sender{[self setNeedsDisplay:YES];[self displayIfNeeded];}
@end
static void addGL(NSView *parent,NSRect frame){
    NSOpenGLPixelFormatAttribute attrs[]={NSOpenGLPFADoubleBuffer,0};
    NSOpenGLPixelFormat *format=[[NSOpenGLPixelFormat alloc]initWithAttributes:attrs];
    GLContent *view=[[GLContent alloc]initWithFrame:frame pixelFormat:format];[format release];
    [parent addSubview:view];[NSTimer scheduledTimerWithTimeInterval:.1 target:view selector:@selector(tick:) userInfo:nil repeats:YES];[view release];
}
@interface DropView : NSView
@end
@implementation DropView
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)info{return NSDragOperationCopy;}
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)info{return NSDragOperationCopy;}
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)info{return YES;}
- (BOOL)performDragOperation:(id<NSDraggingInfo>)info{
    combinedCheck([[ [info draggingPasteboard]stringForType:NSStringPboardType]isEqual:@"Combined Wayland payload"],"drop bytes");
    combinedCheck([info draggingSource]==sourceView,"local source identity");
    NSPoint p=[info draggingLocation];combinedCheck(p.x>0 && p.x<300 && p.y>0 && p.y<220,"parent drop coordinates");
    puts("DROPPED_OVER_GL");fflush(stdout);return failures==0;
}
@end
@interface SourceView : NSView
@end
@implementation SourceView
- (void)drawRect:(NSRect)rect{[[NSColor greenColor]set];NSRectFill([self bounds]);}
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local{return local?NSDragOperationCopy:NSDragOperationNone;}
- (void)hideOrigin:(id)sender{[sourceWindow orderOut:nil];puts("ORIGIN_HIDDEN");fflush(stdout);}
- (void)draggedImage:(NSImage *)image beganAt:(NSPoint)point{
    began++;drawsAtStart[0]=draws[0];drawsAtStart[1]=draws[1];puts("BEGAN");fflush(stdout);
    if([mode isEqual:@"hide"] && attempts==1)[NSTimer scheduledTimerWithTimeInterval:.3 target:self selector:@selector(hideOrigin:) userInfo:nil repeats:NO];
}
- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)op{
    ended++;combinedCheck(draws[0]>drawsAtStart[0] && draws[1]>drawsAtStart[1],"both EGL views rendered during drag");combinedCheck(op==([mode isEqual:@"hide"] && attempts==1?NSDragOperationNone:NSDragOperationCopy),"completion operation");
    printf("ENDED op=%lu\n",(unsigned long)op);fflush(stdout);
}
- (void)mouseDown:(NSEvent *)event{
    attempts++;
    if([mode isEqual:@"modifier"]){
        puts("MODIFIER_GATE_READY");fflush(stdout);int count=0;
        unsigned codes[]={56,60,56,60};NSUInteger flags[]={131074,131078,131076,0};
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
        while([deadline timeIntervalSinceNow]>0){
            NSEvent *next=[NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate date] inMode:NSDefaultRunLoopMode dequeue:YES];
            if([next type]==NSFlagsChanged && [next keyCode]!=65535){
                combinedCheck(count<4 && [next keyCode]==codes[count] && [next modifierFlags]==flags[count],"held-press modifier order");count++;
            }
            usleep(1000);
        }
        combinedCheck(count==4,"four physical modifier transitions");
    }
    NSPasteboard *pb=[NSPasteboard pasteboardWithName:NSDragPboard];[pb declareTypes:@[NSStringPboardType]owner:nil];[pb setString:@"Combined Wayland payload" forType:NSStringPboardType];
    NSImage *image=[[NSImage alloc]initWithSize:NSMakeSize(32,24)];[image lockFocus];[[NSColor yellowColor]set];NSRectFill(NSMakeRect(0,0,32,24));[image unlockFocus];
    NSPoint point=[event locationInWindow];point.x+=20;point.y-=34;
    if([mode isEqual:@"hidepress"] && attempts==1){
        [sourceWindow orderOut:nil];[sourceWindow makeKeyAndOrderFront:nil];
        combinedCheck([[sourceWindow platformWindow]isMapped],"EGL parent remapped before unconsumed press retry");
        [self dragImage:image at:point offset:NSZeroSize event:event pasteboard:pb source:self slideBack:NO];
        combinedCheck(began==0 && ended==0,"unconsumed stale press rejected after remap");
        puts("NEXT_READY");fflush(stdout);[image release];return;
    }
    [self dragImage:image at:point offset:NSZeroSize event:event pasteboard:pb source:self slideBack:NO];
    if([mode isEqual:@"hide"] && attempts==1){
        [self dragImage:image at:point offset:NSZeroSize event:event pasteboard:pb source:self slideBack:NO];
        combinedCheck(began==1 && ended==1,"stale press rejected after EGL parent hide");
        [sourceWindow makeKeyAndOrderFront:nil];
        combinedCheck([[sourceWindow platformWindow]isMapped],"EGL parent remapped before consumed press retry");
        [self dragImage:image at:point offset:NSZeroSize event:event pasteboard:pb source:self slideBack:NO];
        combinedCheck(began==1 && ended==1,"consumed stale press rejected after remap");
        puts("NEXT_READY");fflush(stdout);[image release];return;
    }
    [image release];int expected=attempts-([mode isEqual:@"hidepress"]?1:0);
    combinedCheck(began==expected && ended==expected,"exactly one drag per fresh authorized press");
    printf("RESULT failures=%d draws=%d,%d\n",failures,draws[0],draws[1]);fflush(stdout);exit(failures?1:0);
}
@end
int main(void){
    [NSAutoreleasePool new];[NSApplication sharedApplication];mode=[NSString stringWithUTF8String:getenv("COMBINED_MODE")?:"normal"];
    sourceWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,300,220) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
    [sourceWindow setTitle:@"Combined source"];sourceView=[[SourceView alloc]initWithFrame:NSMakeRect(0,0,300,220)];[sourceWindow setContentView:sourceView];
    addGL(sourceView,NSMakeRect(10,10,40,40));
    NSWindow *target=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,300,220) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
    [target setTitle:@"Combined target"];DropView *view=[[DropView alloc]initWithFrame:NSMakeRect(0,0,300,220)];[view registerForDraggedTypes:@[NSStringPboardType]];[target setContentView:view];
    addGL(view,NSMakeRect(0,0,300,220));[target orderFront:nil];[sourceWindow makeKeyAndOrderFront:nil];puts("READY");fflush(stdout);[NSApp run];return 2;
}
