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
// decodes every type except NSStringPboardType as UTF-16, so a writer that used
// -setString:forType: for URL types would not read back through it.
@interface FakePasteboard : NSPasteboard
@property(retain) NSMutableDictionary *items;
@end

@implementation FakePasteboard
- (NSArray *)types { return [self.items allKeys]; }
- (NSData *)dataForType:(NSPasteboardType)type { return self.items[type]; }
- (BOOL)setData:(NSData *)data forType:(NSPasteboardType)type
{
    if (self.items == nil)
        self.items = [NSMutableDictionary dictionary];
    self.items[type] = data;
    return YES;
}
- (NSString *)stringForType:(NSPasteboardType)type
{
    NSStringEncoding encoding = [type isEqual:NSStringPboardType] ? NSUTF8StringEncoding : NSUnicodeStringEncoding;
    return [[[NSString alloc] initWithData:self.items[type] encoding:encoding] autorelease];
}
@end

@interface Card : NSObject <NSPasteboardWriting>
@end

@implementation Card
- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[ @"com.example.card", @"com.example.card-info", NSStringPboardType, @"com.example.missing" ];
}
- (id)pasteboardPropertyListForType:(NSPasteboardType)type
{
    if ([type isEqual:@"com.example.card"])
        return [@"card-bytes" dataUsingEncoding:NSUTF8StringEncoding];
    if ([type isEqual:@"com.example.card-info"])
        return @{ @"name" : @"Ada" };
    if ([type isEqual:NSStringPboardType])
        return @"Ada";
    return nil;
}
@end

static NSData *utf8(NSString *s) { return [s dataUsingEncoding:NSUTF8StringEncoding]; }

int main(void)
{
    @autoreleasepool
    {
        NSArray *strings = @[ [NSString class] ];
        NSArray *urls = @[ [NSURL class] ];

        FakePasteboard *pb = [[FakePasteboard new] autorelease];
        NSURL *web = [NSURL URLWithString:@"https://example.com/x"];
        expect([pb writeObjects:@[ @"hello", web ]], @"string and web URL are written");
        expect([pb.items[NSStringPboardType] isEqual:utf8(@"hello")], @"string is UTF-8 NSStringPboardType");
        expect([pb.items[NSPasteboardTypeURL] isEqual:utf8(@"https://example.com/x")], @"web URL is UTF-8 public.url data");
        expect([[pb readObjectsForClasses:strings options:nil] isEqual:@[ @"hello" ]], @"round trip: NSString");
        expect([[[pb readObjectsForClasses:urls options:nil][0] absoluteString] isEqual:@"https://example.com/x"],
               @"round trip: web NSURL");

        FakePasteboard *files = [[FakePasteboard new] autorelease];
        NSURL *a = [NSURL fileURLWithPath:@"/Volumes/SystemRoot/a.txt"];
        NSURL *b = [NSURL fileURLWithPath:@"/Volumes/SystemRoot/b.txt"];
        expect([files writeObjects:@[ a, b ]], @"file URLs are written");
        expect([[files.items allKeys] containsObject:NSFilenamesPboardType], @"legacy filenames list is written");
        expect([[[NSString alloc] initWithData:files.items[NSPasteboardTypeFileURL] encoding:NSUTF8StringEncoding]
                       hasPrefix:@"file:"],
               @"public.file-url is UTF-8 URL text");
        NSArray *read = [files readObjectsForClasses:urls options:@{ NSPasteboardURLReadingFileURLsOnlyKey : @YES }];
        expect([read count] == 2 && [[read[0] path] isEqual:@"/Volumes/SystemRoot/a.txt"] &&
                       [[read[1] path] isEqual:@"/Volumes/SystemRoot/b.txt"],
               @"round trip: both file URLs in order");

        FakePasteboard *rich = [[FakePasteboard new] autorelease];
        NSAttributedString *attr = [[[NSAttributedString alloc] initWithString:@"rich text"] autorelease];
        expect([rich writeObjects:@[ attr ]], @"attributed string is written");
        expect(rich.items[NSRTFPboardType] != nil && [rich.items[NSStringPboardType] isEqual:utf8(@"rich text")],
               @"RTF and plain string representations");
        expect([[[rich readObjectsForClasses:@[ [NSAttributedString class] ] options:nil][0] string] containsString:@"rich text"],
               @"round trip: NSAttributedString");

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
        NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(2, 2)] autorelease];
        [image addRepresentation:rep];
        FakePasteboard *pictures = [[FakePasteboard new] autorelease];
        expect([pictures writeObjects:@[ image ]], @"image is written");
        expect(pictures.items[NSTIFFPboardType] != nil, @"image is TIFF");
        expect([[pictures readObjectsForClasses:@[ [NSImage class] ] options:nil][0] isKindOfClass:[NSImage class]],
               @"round trip: NSImage");

        // NSPasteboardWriting conformers: data, string and plist payloads; a nil payload is skipped.
        FakePasteboard *cards = [[FakePasteboard new] autorelease];
        expect([cards writeObjects:@[ [[Card new] autorelease] ]], @"conforming object is written");
        expect([cards.items[@"com.example.card"] isEqual:utf8(@"card-bytes")], @"NSData payload is stored as is");
        expect([[cards propertyListForType:@"com.example.card-info"] isEqual:@{ @"name" : @"Ada" }], @"plist payload round trips");
        expect([cards.items[NSStringPboardType] isEqual:utf8(@"Ada")], @"string payload for NSStringPboardType is UTF-8");
        expect(cards.items[@"com.example.missing"] == nil, @"nil payload writes nothing");

        // Unsupported input returns NO and never raises; writable objects in the same call still land.
        FakePasteboard *mixed = [[FakePasteboard new] autorelease];
        expect(![mixed writeObjects:@[ @42, @"kept" ]], @"unsupported object makes the call NO");
        expect([mixed.items[NSStringPboardType] isEqual:utf8(@"kept")], @"supported objects are still written");
        expect(![[[FakePasteboard new] autorelease] writeObjects:@[ [[NSPasteboardItem new] autorelease] ]],
               @"NSPasteboardItem is skipped with NO");
        expect(![[[FakePasteboard new] autorelease] writeObjects:nil], @"nil array is NO");
        expect([[[FakePasteboard new] autorelease] writeObjects:@[]], @"empty array writes nothing and fails nothing");

        // Known divergence from Apple (one item per object, YES): the single-item board
        // keeps the first object to supply a type and returns NO for the dropped one.
        FakePasteboard *dup = [[FakePasteboard new] autorelease];
        expect(![dup writeObjects:@[ @"first", @"second" ]], @"a second string has no free type");
        expect([dup.items[NSStringPboardType] isEqual:utf8(@"first")], @"first string wins");

        for (FakePasteboard *written in @[ pb, files, rich, pictures, cards ])
            for (NSString *type in [written.items allKeys])
                expect(![type isEqual:NSPasteboardTypeHTML] && ![type isEqual:NSHTMLPboardType], @"no HTML type is written");

        NSLog(@"PASS: NSPasteboard writes objects");
    }
    return 0;
}
