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
#import <AppKit/NSGraphics.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSTextAttachment.h>
#import <AppKit/NSTextAttachmentCell.h>
#include <string.h>

static NSImage *imageForAttachment(NSTextAttachment *attachment) {
    NSImage *image = [attachment image];
    if (image != nil)
        return image;
    NSData *contents = [attachment contents];
    const unsigned char *bytes = [contents bytes];
    NSUInteger length = [contents length];
    // NSImage's decoders assume image data; file-wrapper attachments can hold
    // arbitrary files. Check the formats AppKit can display before decoding.
    BOOL tiff = length >= 4 &&
        ((bytes[0] == 'I' && bytes[1] == 'I' && bytes[2] == 42 && bytes[3] == 0) ||
         (bytes[0] == 'M' && bytes[1] == 'M' && bytes[2] == 0 && bytes[3] == 42));
    BOOL png = length >= 8 &&
        memcmp(bytes, "\x89PNG\r\n\x1a\n", 8) == 0;
    BOOL jpeg = length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    BOOL gif = length >= 6 &&
        (memcmp(bytes, "GIF87a", 6) == 0 || memcmp(bytes, "GIF89a", 6) == 0);
    if (!tiff && !png && !jpeg && !gif)
        return nil;
    return [[[NSImage alloc] initWithData: contents] autorelease];
}

@implementation NSTextAttachmentCell

- (NSTextAttachment *) attachment {
    return _attachment;
}

- (void) setAttachment: (NSTextAttachment *) attachment {
    _attachment = attachment;
}

- (NSSize) cellSize {
    CGRect bounds = [_attachment bounds];
    if (!CGRectIsEmpty(bounds))
        return bounds.size;
    NSImage *image = imageForAttachment(_attachment);
    return image == nil ? NSZeroSize : [image size];
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
    return NSMakeRect(glyphPoint.x, glyphPoint.y,
                      [self cellSize].width, [self cellSize].height);
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
    [self drawWithFrame: frame inView: view];
}

- (void) drawWithFrame: (NSRect) frame
                inView: (NSView *) view
        characterIndex: (unsigned) characterIndex
{
    [self drawWithFrame: frame inView: view];
}

- (void) drawWithFrame: (NSRect) frame inView: (NSView *) view {
    NSImage *image = imageForAttachment(_attachment);
    if (image != nil)
        [image drawInRect: frame
                fromRect: NSZeroRect
               operation: NSCompositeSourceOver
                fraction: 1.0];
}

@end
