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

static NSString *raisedName(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [exception name];
    }
    return nil;
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
    expect(element.childElements != nil && [element.childElements count] == 0,
           @"GUESS: an element made here has an empty (not nil) array of children");
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

    // NSTextListElement inherits from NSTextParagraph (documented) and has the members of its page.
    expect(NSClassFromString(@"NSTextListElement") != Nil && [NSTextListElement superclass] == [NSTextParagraph class],
           @"NSTextListElement inherits from NSTextParagraph (documented)");
    NSTextList *list = [[[NSTextList alloc] initWithMarkerFormat:@"{decimal}" options:0] autorelease];
    NSAttributedString *childText = [[[NSAttributedString alloc] initWithString:@"child"] autorelease];
    NSTextListElement *child = [NSTextListElement textListElementWithContents:childText markerAttributes:nil textList:list
                                                                childElements:nil];
    expect(child.textList == list && [child.contents isEqual:childText] && child.markerAttributes == nil &&
               child.parentElement == nil,
           @"a list element keeps its list and contents");
    expect(child.childElements != nil && [child.childElements count] == 0, @"GUESS: no children is an empty array, not nil");
    NSDictionary *marker = @{NSForegroundColorAttributeName : [NSColor redColor]};
    NSAttributedString *text = [[[NSAttributedString alloc] initWithString:@"item\n"] autorelease];
    NSTextListElement *item = [[[NSTextListElement alloc] initWithParentElement:nil textList:list contents:text
                                                               markerAttributes:marker childElements:@[ child ]] autorelease];
    expect([item.markerAttributes isEqual:marker] && [item.childElements isEqual:@[ child ]],
           @"the initializer keeps the marker attributes and the children");
    NSTextListElement *nested = [[[NSTextListElement alloc] initWithParentElement:item textList:list contents:childText
                                                                 markerAttributes:nil childElements:nil] autorelease];
    expect(nested.parentElement == item, @"the parent is the one the initializer was given");
    item.textContentManager = content;
    item.elementRange = [[[NSTextRange alloc] initWithLocation:content.documentRange.location
                                                   endLocation:[content locationFromLocation:content.documentRange.location
                                                                                  withOffset:5]] autorelease];
    expect(NSEqualRanges(offsets(content, item.paragraphContentRange), NSMakeRange(0, 4)) &&
               NSEqualRanges(offsets(content, item.paragraphSeparatorRange), NSMakeRange(4, 1)),
           @"the paragraph ranges of a list element are those of its contents");
    expect([raisedName(^{ (void) item.attributedString; }) isEqual:NSInvalidArgumentException],
           @"GUESS: attributedString (contents with the marker) raises, there is no list marker layout");
    expect([raisedName(^{ [NSTextListElement textListElementWithChildElements:@[ child ] textList:list nestingLevel:1]; })
               isEqual:NSInvalidArgumentException],
           @"GUESS: the nesting level factory raises");

    // Weak references clear when their target goes away (Apple declares them weak).
    NSTextElement *weakHolder = [[[NSTextElement alloc] init] autorelease];
    @autoreleasepool {
        NSTextContentStorage *shortLived = [[NSTextContentStorage alloc] init];
        weakHolder.textContentManager = shortLived;
        expect(weakHolder.textContentManager == shortLived, @"the content manager is kept while it lives");
        [shortLived release];
    }
    expect(weakHolder.textContentManager == nil, @"the content manager is weak: nil once it is gone");

    [pool drain];
    printf("PASS: NSTextElement and NSTextParagraph\n");
    return 0;
}
