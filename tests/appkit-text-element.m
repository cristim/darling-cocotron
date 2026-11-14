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

static NSRange offsets(NSTextContentManager *manager, NSTextRange *range)
{
    NSTextRange *document = manager.documentRange;
    NSInteger from = [manager offsetFromLocation:document.location toLocation:range.location];
    NSInteger to = [manager offsetFromLocation:document.location toLocation:range.endLocation];
    return NSMakeRange(from, to - from);
}

int main(void)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    expect(NSClassFromString(@"NSTextElement") != Nil && NSClassFromString(@"NSTextParagraph") != Nil,
           @"the classes exist");
    expect([NSTextParagraph superclass] == [NSTextElement class], @"NSTextParagraph derives from NSTextElement");

    NSTextContentStorage *content = [[[NSTextContentStorage alloc] init] autorelease];
    content.attributedString = [[[NSAttributedString alloc] initWithString:@"first\nsecond"] autorelease];

    NSTextElement *element = [[[NSTextElement alloc] initWithTextContentManager:content] autorelease];
    expect(element.textContentManager == content, @"the initializer keeps the content manager");
    expect(element.elementRange == nil, @"a new element has no range");
    NSTextRange *range = content.documentRange;
    element.elementRange = range;
    expect(element.elementRange == range, @"elementRange is settable");
    element.textContentManager = nil;
    expect(element.textContentManager == nil, @"textContentManager is settable");
    expect(element.parentElement == nil, @"GUESS: an element made here has no parent");
    expect([element.childElements count] == 0, @"GUESS: an element made here has no children");
    expect(!element.isRepresentedElement, @"GUESS: an element made here is not in any layout");

    NSAttributedString *source = [[[NSAttributedString alloc] initWithString:@"first\n"] autorelease];
    NSTextParagraph *paragraph = [[[NSTextParagraph alloc] initWithAttributedString:source] autorelease];
    expect([paragraph.attributedString isEqual:source], @"the paragraph keeps its attributed string");
    expect(paragraph.paragraphContentRange == nil && paragraph.paragraphSeparatorRange == nil,
           @"GUESS: without an element range and a content manager the two ranges are nil");

    NSTextRange *first = [[[NSTextRange alloc] initWithLocation:content.documentRange.location
                                                    endLocation:[content locationFromLocation:content.documentRange.location
                                                                                  withOffset:6]] autorelease];
    paragraph.textContentManager = content;
    paragraph.elementRange = first;
    NSRange contentRange = offsets(content, paragraph.paragraphContentRange);
    NSRange separatorRange = offsets(content, paragraph.paragraphSeparatorRange);
    expect(NSEqualRanges(contentRange, NSMakeRange(0, 5)), @"the content range excludes the separator");
    expect(NSEqualRanges(separatorRange, NSMakeRange(5, 1)), @"the separator range is the newline");

    NSTextParagraph *last = [[[NSTextParagraph alloc] initWithAttributedString:
                                  [[[NSAttributedString alloc] initWithString:@"second"] autorelease]] autorelease];
    last.textContentManager = content;
    last.elementRange = [[[NSTextRange alloc] initWithLocation:[content locationFromLocation:content.documentRange.location
                                                                                  withOffset:6]
                                                   endLocation:content.documentRange.endLocation] autorelease];
    expect(offsets(content, last.paragraphContentRange).length == 6, @"a paragraph without a separator is all content");
    expect(last.paragraphSeparatorRange == nil, @"GUESS: a paragraph without a separator has a nil separator range");

    NSTextParagraph *empty = [[[NSTextParagraph alloc] initWithAttributedString:nil] autorelease];
    expect([empty.attributedString length] == 0, @"GUESS: a nil attributed string makes an empty paragraph");

    expect(NSClassFromString(@"NSTextListElement") != Nil && [NSTextListElement superclass] == [NSTextElement class],
           @"GUESS: NSTextListElement exists and derives from NSTextElement");

    [pool drain];
    printf("PASS: NSTextElement and NSTextParagraph\n");
    return 0;
}
