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

// In-memory pasteboard: no display connection is needed. Like the backends, it
// decodes every type except NSStringPboardType as UTF-16.
@interface FakePasteboard : NSPasteboard
@property(retain) NSMutableDictionary *items;
@end

@implementation FakePasteboard
- (NSArray *)types { return [self.items allKeys]; }
- (NSData *)dataForType:(NSPasteboardType)type { return self.items[type]; }
- (NSString *)stringForType:(NSPasteboardType)type
{
    NSStringEncoding encoding = [type isEqual:NSStringPboardType] ? NSUTF8StringEncoding : NSUnicodeStringEncoding;
    return [[[NSString alloc] initWithData:self.items[type] encoding:encoding] autorelease];
}
@end

static FakePasteboard *board(NSDictionary *items)
{
    FakePasteboard *pb = [[FakePasteboard new] autorelease];
    pb.items = [[items mutableCopy] autorelease];
    return pb;
}

static NSData *utf8(NSString *s) { return [s dataUsingEncoding:NSUTF8StringEncoding]; }

int main(void)
{
    @autoreleasepool
    {
        NSArray *strings = @[ [NSString class] ];
        NSArray *urls = @[ [NSURL class] ];

        FakePasteboard *text = board(@{ NSStringPboardType : utf8(@"hello") });
        expect([[text readObjectsForClasses:strings options:nil] isEqual:@[ @"hello" ]], @"NSString read");
        expect([text canReadObjectForClasses:strings options:nil], @"can read NSString");
        expect(![text canReadObjectForClasses:urls options:nil], @"text is not an NSURL");
        expect([text readObjectsForClasses:urls options:nil] == nil, @"nothing readable returns nil");

        NSArray *both = @[ [NSURL class], [NSString class] ];
        expect([[text readObjectsForClasses:both options:nil] isEqual:@[ @"hello" ]],
               @"class order falls through to the first class that can read the item");

        NSAttributedString *attr = [text readObjectsForClasses:@[ [NSAttributedString class] ] options:nil][0];
        expect([[attr string] isEqual:@"hello"], @"plain text reads as NSAttributedString");

        NSArray *paths = @[ @"/Volumes/SystemRoot/a.txt", @"/Volumes/SystemRoot/b.txt" ];
        NSData *plist = [NSPropertyListSerialization dataFromPropertyList:paths
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                         errorDescription:NULL];
        FakePasteboard *files = board(@{ NSFilenamesPboardType : plist, NSStringPboardType : utf8(@"a.txt") });
        NSDictionary *fileOnly = @{ NSPasteboardURLReadingFileURLsOnlyKey : @YES };
        NSArray *read = [files readObjectsForClasses:urls options:fileOnly];
        expect([read count] == 2 && [read[0] isFileURL] && [[read[1] path] isEqual:paths[1]],
               @"each filename is one file NSURL, in order");
        expect([files canReadObjectForClasses:urls options:fileOnly], @"can read file URLs");

        FakePasteboard *fileURL = board(@{ NSPasteboardTypeFileURL : utf8(@"file:///Volumes/SystemRoot/c.txt") });
        expect([[[fileURL readObjectsForClasses:urls options:fileOnly][0] path] isEqual:@"/Volumes/SystemRoot/c.txt"],
               @"public.file-url reads as a file NSURL");

        FakePasteboard *web = board(@{ NSPasteboardTypeURL : utf8(@"https://example.com/x") });
        expect([[[web readObjectsForClasses:urls options:nil][0] absoluteString] isEqual:@"https://example.com/x"],
               @"public.url reads as NSURL");
        expect([web readObjectsForClasses:urls options:fileOnly] == nil,
               @"FileURLsOnly excludes non-file URLs");
        expect(![web canReadObjectForClasses:urls options:fileOnly], @"FileURLsOnly excludes non-file URLs (can read)");

        expect([files canReadItemWithDataConformingToTypes:@[ @"public.url" ]],
               @"file URLs conform to public.url");
        expect([text canReadItemWithDataConformingToTypes:@[ @"public.text" ]], @"plain text conforms to public.text");
        expect(![text canReadItemWithDataConformingToTypes:@[ @"public.png" ]], @"text is not a PNG");
        expect(![text canReadItemWithDataConformingToTypes:@[]], @"empty request is NO");

        // Unsupported classes and options never raise; they read as "no match".
        expect([text readObjectsForClasses:@[ [NSNumber class] ] options:nil] == nil, @"unsupported class reads nil");
        expect(![text canReadObjectForClasses:@[ [NSPasteboardItem class] ] options:nil], @"NSPasteboardItem is skipped");
        expect([[text readObjectsForClasses:@[ [NSNumber class], [NSString class] ] options:nil] isEqual:@[ @"hello" ]],
               @"an unsupported class does not stop later classes");
        expect([[text readObjectsForClasses:@[ [NSString class], [NSNumber class] ] options:nil] isEqual:@[ @"hello" ]],
               @"an unsupported class after a match is harmless");

        // Peer-supplied filename lists with non-string entries are ignored.
        NSData *badPlist = [NSPropertyListSerialization dataFromPropertyList:@[ @42, @"/Volumes/SystemRoot/ok.png", @[] ]
                                                                      format:NSPropertyListXMLFormat_v1_0
                                                            errorDescription:NULL];
        FakePasteboard *bad = board(@{ NSFilenamesPboardType : badPlist });
        read = [bad readObjectsForClasses:urls options:fileOnly];
        expect([read count] == 1 && [[read[0] path] isEqual:@"/Volumes/SystemRoot/ok.png"], @"malformed entries are skipped");
        expect([board(@{ NSFilenamesPboardType : utf8(@"not a plist") }) readObjectsForClasses:urls options:nil] == nil,
               @"an unparseable filename list reads nil");

        // Contents-conform filter on file URLs.
        FakePasteboard *mixed = board(@{
            NSFilenamesPboardType : [NSPropertyListSerialization
                    dataFromPropertyList:@[ @"/Volumes/SystemRoot/a.png", @"/Volumes/SystemRoot/b.txt", @"/Volumes/SystemRoot/noext" ]
                                  format:NSPropertyListXMLFormat_v1_0
                        errorDescription:NULL] });
        NSDictionary *images = @{ NSPasteboardURLReadingFileURLsOnlyKey : @YES,
                                  NSPasteboardURLReadingContentsConformToTypesKey : @[ @"public.image" ] };
        read = [mixed readObjectsForClasses:urls options:images];
        expect([read count] == 1 && [[read[0] path] isEqual:@"/Volumes/SystemRoot/a.png"], @"only image files pass the filter");
        expect([mixed canReadObjectForClasses:urls options:images], @"can read matches the filtered read");
        expect(![mixed canReadObjectForClasses:urls
                                       options:@{ NSPasteboardURLReadingContentsConformToTypesKey : @[ @"public.movie" ] }],
               @"no file conforms, so nothing is readable");

        // RTF reads as rich text; unreadable RTF falls back to the plain string.
        NSData *rtf = [@"{\\rtf1 rich}" dataUsingEncoding:NSASCIIStringEncoding];
        FakePasteboard *rich = board(@{ NSRTFPboardType : rtf });
        expect([[[rich readObjectsForClasses:@[ [NSAttributedString class] ] options:nil][0] string] containsString:@"rich"],
               @"RTF reads as NSAttributedString");
        FakePasteboard *brokenRTF = board(@{ NSRTFPboardType : utf8(@"not rtf"), NSStringPboardType : utf8(@"plain") });
        expect([[[brokenRTF readObjectsForClasses:@[ [NSAttributedString class] ] options:nil][0] string] isEqual:@"plain"],
               @"unreadable RTF falls back to the plain string");
        expect(![board(@{ NSRTFPboardType : utf8(@"not rtf") }) canReadObjectForClasses:@[ [NSAttributedString class] ]
                                                                                options:nil],
               @"can read agrees with an unreadable RTF");

        // A web URL is never returned once a contents filter limits results to files.
        expect([web readObjectsForClasses:urls
                                  options:@{ NSPasteboardURLReadingContentsConformToTypesKey : @[ @"public.image" ] }] == nil,
               @"a contents filter excludes non-file URLs");
        FakePasteboard *emptyURL = board(@{ NSPasteboardTypeURL : utf8(@"") });
        expect(![emptyURL canReadObjectForClasses:urls options:nil], @"empty URL data is not readable");

        // NSImage.
        NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                         pixelsWide:2
                                                                         pixelsHigh:2
                                                                      bitsPerSample:8
                                                                    samplesPerPixel:4
                                                                           hasAlpha:YES
                                                                           isPlanar:NO
                                                                     colorSpaceName:NSDeviceRGBColorSpace
                                                                        bytesPerRow:0
                                                                       bitsPerPixel:0] autorelease];
        FakePasteboard *image = board(@{ NSTIFFPboardType : [rep TIFFRepresentation] });
        expect([[image readObjectsForClasses:@[ [NSImage class] ] options:nil][0] isKindOfClass:[NSImage class]],
               @"TIFF reads as NSImage");

        NSLog(@"PASS: NSPasteboard reads objects by class");
    }
    return 0;
}
