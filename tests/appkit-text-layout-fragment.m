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

// Nothing in this tree lays a fragment out, so every answer below is the documented "no layout yet" value or a
// GUESS (not in the public documentation, not observed); the GUESS EXPECT messages say which.
int main(void)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    expect(NSClassFromString(@"NSTextLayoutFragment") != Nil, @"the class exists");

    NSTextContentStorage *content = [[[NSTextContentStorage alloc] init] autorelease];
    content.attributedString = [[[NSAttributedString alloc] initWithString:@"abc"] autorelease];
    NSTextParagraph *paragraph = [[[NSTextParagraph alloc] initWithAttributedString:content.attributedString] autorelease];
    paragraph.textContentManager = content;
    paragraph.elementRange = content.documentRange;

    NSTextRange *sub = [[[NSTextRange alloc] initWithLocation:content.documentRange.location
                                                  endLocation:[content locationFromLocation:content.documentRange.location
                                                                                withOffset:2]] autorelease];
    NSTextLayoutFragment *fragment = [[[NSTextLayoutFragment alloc] initWithTextElement:paragraph range:sub] autorelease];
    expect(fragment.textElement == paragraph && fragment.rangeInElement == sub,
           @"the initializer keeps the element and the range");
    NSTextLayoutFragment *whole = [[[NSTextLayoutFragment alloc] initWithTextElement:paragraph range:nil] autorelease];
    expect(whole.rangeInElement == paragraph.elementRange, @"GUESS: a nil range is the element's whole range");

    expect(fragment.state == NSTextLayoutFragmentStateNone, @"no layout information is available (documented state none)");
    expect(fragment.textLayoutManager == nil, @"GUESS: no layout manager made the fragment");
    expect(fragment.textLineFragments != nil && [fragment.textLineFragments count] == 0,
           @"line fragments exist only once layout is available: an empty array, not nil");
    expect([fragment textLineFragmentForTextLocation:sub.location isUpstreamAffinity:NO] == nil &&
               [fragment textLineFragmentForVerticalOffset:3 requiresExactMatch:NO] == nil,
           @"no line fragment matches without layout");
    expect(CGRectEqualToRect(fragment.layoutFragmentFrame, CGRectZero) &&
               CGRectEqualToRect(fragment.renderingSurfaceBounds, CGRectZero),
           @"GUESS: both rectangles are empty before layout");
    expect(fragment.leadingPadding == 0 && fragment.trailingPadding == 0 && fragment.topMargin == 0 &&
               fragment.bottomMargin == 0,
           @"GUESS: margins and paddings are 0 before layout");
    expect(fragment.textAttachmentViewProviders != nil && [fragment.textAttachmentViewProviders count] == 0,
           @"no attachment view providers without layout: an empty array, not nil");
    expect(CGRectEqualToRect([fragment frameForTextAttachmentAtLocation:sub.location], CGRectZero),
           @"the attachment frame is CGRectZero unless layout is available (documented)");

    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
    fragment.layoutQueue = queue;
    expect(fragment.layoutQueue == queue, @"layoutQueue is settable");
    [fragment invalidateLayout];
    expect(fragment.state == NSTextLayoutFragmentStateNone, @"GUESS: invalidating an unlaid fragment changes nothing");

    expect(NSTextLayoutFragmentStateLayoutAvailable > NSTextLayoutFragmentStateNone, @"GUESS: layoutAvailable follows none");

    NSTextLayoutFragment *weakFragment = nil;
    @autoreleasepool {
        NSTextParagraph *shortLived = [[NSTextParagraph alloc] initWithAttributedString:content.attributedString];
        weakFragment = [[NSTextLayoutFragment alloc] initWithTextElement:shortLived range:nil];
        expect(weakFragment.textElement == shortLived, @"the element is kept while it lives");
        [shortLived release];
    }
    expect(weakFragment.textElement == nil, @"the text element is weak (documented): nil once it is gone");
    [weakFragment release];

    BOOL raised = NO;
    @try {
        [[NSTextLayoutFragment alloc] initWithCoder:nil];
    } @catch (NSException *exception) {
        raised = [[exception name] isEqual:NSInvalidArgumentException];
    }
    expect(raised, @"GUESS: initWithCoder: fails loudly");

    [pool drain];
    printf("PASS: NSTextLayoutFragment\n");
    return 0;
}
