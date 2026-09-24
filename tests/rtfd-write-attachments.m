#import <AppKit/AppKit.h>
#include <stdlib.h>

// -[NSText writeRTFDToFile:atomically:] (what Stickies saves notes with) must
// store attachment files in the .rtfd and reference them from TXT.rtf, so the
// reader brings them back.
static void expect(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        NSString *path = [NSTemporaryDirectory()
                stringByAppendingPathComponent: @"rtfd-write-attachments.rtfd"];
        [[NSFileManager defaultManager] removeItemAtPath: path error: NULL];

        NSData *payload = [@"attachment payload" dataUsingEncoding: NSUTF8StringEncoding];
        NSFileWrapper *file = [[[NSFileWrapper alloc] initRegularFileWithContents: payload] autorelease];
        [file setPreferredFilename: @"picture.tif"];
        NSTextAttachment *attachment = [[[NSTextAttachment alloc] initWithFileWrapper: file] autorelease];

        NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] initWithString: @"before "] autorelease];
        [text appendAttributedString: [NSAttributedString attributedStringWithAttachment: attachment]];
        [text appendAttributedString: [[[NSAttributedString alloc] initWithString: @" after"] autorelease]];

        NSTextView *view = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 300, 100)] autorelease];
        [[view textStorage] setAttributedString: text];
        expect([view writeRTFDToFile: path atomically: YES], @"writeRTFDToFile:atomically:");

        NSData *stored = [NSData dataWithContentsOfFile: [path stringByAppendingPathComponent: @"picture.tif"]];
        expect([stored isEqualToData: payload], @"attachment file stored in the .rtfd");
        NSString *rtf = [NSString stringWithContentsOfFile: [path stringByAppendingPathComponent: @"TXT.rtf"]
                                                  encoding: NSISOLatin1StringEncoding
                                                     error: NULL];
        expect([rtf rangeOfString: @"\\NeXTGraphic picture.tif "].location != NSNotFound,
               @"TXT.rtf references the attachment");

        NSTextView *reader = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 300, 100)] autorelease];
        expect([reader readRTFDFromFile: path], @"readRTFDFromFile:");
        NSTextStorage *read = [reader textStorage];
        expect([[read string] isEqualToString: [text string]], @"text round-trips with one attachment character");
        NSTextAttachment *readAttachment = [read attribute: NSAttachmentAttributeName
                                                   atIndex: [@"before " length]
                                            effectiveRange: NULL];
        expect([[[readAttachment fileWrapper] regularFileContents] isEqualToData: payload],
               @"attachment contents round-trip");
        NSLog(@"PASS: rtfd-write-attachments");
    }
    return 0;
}
