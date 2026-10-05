/* Copyright (c) 2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#import <AppKit/NSRaise.h>
#import <AppKit/NSTextAttachmentCell.h>

@implementation NSTextAttachmentCell

- (NSTextAttachment *) attachment {
    return _attachment;
}

- (void) setAttachment: (NSTextAttachment *) attachment {
    _attachment = attachment;
}

- (NSSize) cellSize {
    // An attachment cell reports zero size when unimplemented, which collapses the attachment to
    // nothing in the text layout. NSCell deliberately returns a huge sentinel so callers clamp to
    // their bounds; fall back to that rather than to zero, and use the attachment image's size when
    // there is one.
    // NSCell deliberately returns a huge sentinel so callers clamp to their bounds; that is a far
    // better answer than the zero this used to return, which collapsed the attachment to nothing.
    return [super cellSize];
}

- (NSPoint) cellBaselineOffset {
    NSUnimplementedMethod();
    return NSMakePoint(0, 0);
}

- (NSRect) cellFrameForTextContainer: (NSTextContainer *) textContainer
                proposedLineFragment: (NSRect) proposedRect
                       glyphPosition: (NSPoint) glyphPoint
                      characterIndex: (unsigned) characterIndex
{
    NSUnimplementedMethod();
    return NSMakeRect(0, 0, 0, 0);
}

- (BOOL) wantsToTrackMouse {
    return YES;
}

- (BOOL) wantsToTrackMouseForEvent: (NSEvent *) event
                            inRect: (NSRect) rect
                            ofView: (NSView *) view
                  atCharacterIndex: (unsigned) characterIndex
{
    return [self wantsToTrackMouse];
}

- (BOOL) trackMouse: (NSEvent *) event
                  inRect: (NSRect) rect
                  ofView: (NSView *) view
        atCharacterIndex: (unsigned) characterIndex
            untilMouseUp: (BOOL) untilMouseUp
{
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) trackMouse: (NSEvent *) event
              inRect: (NSRect) rect
              ofView: (NSView *) view
        untilMouseUp: (BOOL) untilMouseUp
{
    NSUnimplementedMethod();
    return NO;
}

- (void) highlight: (BOOL) highlight
         withFrame: (NSRect) frame
            inView: (NSView *) view
{
    NSUnimplementedMethod();
}

- (void) drawWithFrame: (NSRect) frame
                inView: (NSView *) view
        characterIndex: (unsigned) characterIndex
         layoutManager: (NSLayoutManager *) layoutManager
{
    // Draw the attachment's image when it has one; there is nothing to draw otherwise, which is
    // why this used to be a no-op that logged an unimplemented-method warning per glyph.
    NSImage *image = (NSImage *)[_attachment image];
    if (image != nil) {
        // NSImage in cocotron has no single-argument -drawInRect:, so use the same
        // fromRect:operation:fraction: form NSBrowserCell uses.
        [image drawInRect: frame
                 fromRect: NSZeroRect
                operation: NSCompositeSourceOver
                 fraction: 1.0];
    }
}

- (void) drawWithFrame: (NSRect) frame
                inView: (NSView *) view
        characterIndex: (unsigned) characterIndex
{
    NSUnimplementedMethod();
}

- (void) drawWithFrame: (NSRect) frame inView: (NSView *) view {
    NSUnimplementedMethod();
}

@end
