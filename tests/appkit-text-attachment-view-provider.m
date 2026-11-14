#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface LoadingProvider : NSTextAttachmentViewProvider
@property(assign) int loads;
@end

@implementation LoadingProvider
- (void)loadView
{
    self.loads++;
    self.view = [[[NSView alloc] initWithFrame:NSMakeRect(5, 6, 30, 20)] autorelease];
}
@end

@interface QuietProvider : NSTextAttachmentViewProvider
@property(assign) int loads;
@end

@implementation QuietProvider
- (void)loadView
{
    self.loads++;
}
@end

int main(void)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    expect(NSClassFromString(@"NSTextAttachmentViewProvider") != Nil, @"the class exists");
    expect([NSTextAttachmentViewProvider superclass] == [NSObject class], @"it derives from NSObject");

    NSTextContentStorage *content = [[[NSTextContentStorage alloc] init] autorelease];
    content.attributedString = [[[NSAttributedString alloc] initWithString:@"x"] autorelease];
    id<NSTextLocation> location = content.documentRange.location;
    NSTextLayoutManager *layoutManager = [[[NSTextLayoutManager alloc] init] autorelease];
    NSTextAttachment *attachment = [[[NSTextAttachment alloc] initWithData:[NSData data] ofType:@"public.data"] autorelease];
    attachment.bounds = CGRectMake(0, 0, 11, 12);

    NSTextAttachmentViewProvider *provider = [[[NSTextAttachmentViewProvider alloc] initWithTextAttachment:attachment
                                                                                                parentView:nil
                                                                                         textLayoutManager:layoutManager
                                                                                                  location:location] autorelease];
    expect(provider.textAttachment == attachment, @"the initializer keeps the text attachment");
    expect(provider.textLayoutManager == layoutManager, @"the initializer keeps the text layout manager");
    expect(provider.location == location, @"the initializer keeps the location");
    expect(!provider.tracksTextAttachmentViewBounds, @"tracksTextAttachmentViewBounds defaults to NO (documented)");
    provider.tracksTextAttachmentViewBounds = YES;
    expect(provider.tracksTextAttachmentViewBounds, @"tracksTextAttachmentViewBounds is settable");

    expect(provider.view == nil, @"GUESS: the base class makes no view (its -loadView does nothing)");
    [provider loadView];
    expect(provider.view == nil, @"GUESS: the base -loadView does nothing");
    CGRect bounds = [provider attachmentBoundsForAttributes:@{} location:location textContainer:nil
                                       proposedLineFragment:CGRectMake(0, 0, 100, 14) position:CGPointMake(3, 4)];
    expect(CGRectEqualToRect(bounds, CGRectMake(0, 0, 11, 12)),
           @"GUESS: the default bounds are the attachment's own when they are not empty");

    NSTextAttachment *empty = [[[NSTextAttachment alloc] initWithData:[NSData data] ofType:@"public.data"] autorelease];
    NSTextAttachmentViewProvider *viewOnly = [[[NSTextAttachmentViewProvider alloc] initWithTextAttachment:empty
                                                                                                parentView:nil
                                                                                         textLayoutManager:nil
                                                                                                  location:location] autorelease];
    NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(5, 6, 30, 20)] autorelease];
    viewOnly.view = view;
    expect(viewOnly.view == view, @"view is settable");
    bounds = [viewOnly attachmentBoundsForAttributes:@{} location:location textContainer:nil
                                proposedLineFragment:CGRectMake(0, 0, 100, 14) position:CGPointMake(3, 4)];
    expect(CGRectEqualToRect(bounds, CGRectMake(0, 0, 30, 20)),
           @"GUESS: with empty attachment bounds the default bounds are the view's size at the origin");

    LoadingProvider *custom = [[[LoadingProvider alloc] initWithTextAttachment:attachment parentView:nil
                                                             textLayoutManager:nil location:location] autorelease];
    expect(custom.loads == 0, @"GUESS: creating a provider does not call -loadView");
    expect(custom.view != nil && custom.loads == 1, @"GUESS: the view getter calls a subclass's -loadView once");
    expect(custom.view != nil && custom.loads == 1, @"GUESS: -loadView is not called again");

    QuietProvider *quiet = [[[QuietProvider alloc] initWithTextAttachment:attachment parentView:nil textLayoutManager:nil
                                                                 location:location] autorelease];
    expect(quiet.view == nil && quiet.view == nil && quiet.loads == 1,
           @"GUESS: -loadView runs once even when it leaves the view nil");

    NSTextAttachmentViewProvider *weakProvider = nil;
    @autoreleasepool {
        NSTextAttachment *shortLived = [[NSTextAttachment alloc] initWithData:[NSData data] ofType:@"public.data"];
        weakProvider = [[[NSTextAttachmentViewProvider alloc] initWithTextAttachment:shortLived parentView:nil
                                                                   textLayoutManager:nil location:location] autorelease];
        expect(weakProvider.textAttachment == shortLived, @"the attachment is kept while it lives");
        [shortLived release];
    }
    expect(weakProvider.textAttachment == nil, @"the text attachment is weak (documented): nil once it is gone");

    BOOL raised = NO;
    @try {
        [[NSTextAttachmentViewProvider alloc] init];
    } @catch (NSException *exception) {
        raised = [[exception name] isEqual:NSInvalidArgumentException];
    }
    expect(raised, @"GUESS: plain -init raises NSInvalidArgumentException");

    [NSTextAttachment registerTextAttachmentViewProviderClass:[LoadingProvider class] forFileType:@"public.data"];
    attachment.allowsTextAttachmentView = YES;
    expect(attachment.usesTextAttachmentView, @"a registered provider class enables attachment views");
    NSTextAttachmentViewProvider *made = [attachment viewProviderForParentView:nil location:location textContainer:nil];
    expect([made isMemberOfClass:[LoadingProvider class]] && made.textAttachment == attachment && made.location == location,
           @"the attachment makes a provider of the registered class and passes itself and the location");

    [pool drain];
    printf("PASS: NSTextAttachmentViewProvider\n");
    return 0;
}
