/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

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

#import <AppKit/NSAttributedString.h>
#import <AppKit/NSDisplay.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSPasteboard.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSWorkspace.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <dispatch/dispatch.h>

const NSPasteboardType NSPasteboardTypeString = @"NSStringPboardType";
const NSPasteboardType NSPasteboardTypePDF = @"NSPDFPboardType";
const NSPasteboardType NSPasteboardTypePNG = @"public.png";
const NSPasteboardType NSPasteboardTypeTIFF = @"NSTIFFPboardType";
const NSPasteboardType NSPasteboardTypeRTF = @"NSRTFPboardType";
const NSPasteboardType NSPasteboardTypeRTFD = @"NSRTFDPboardType";
const NSPasteboardType NSPasteboardTypeHTML = @"NSPasteboardTypeHTML";
const NSPasteboardType NSPasteboardTypeTabularText = @"NSTabularTextPboardType";
const NSPasteboardType NSPasteboardTypeFont = @"NSFontPboardType";
const NSPasteboardType NSPasteboardTypeRuler = @"NSRulerPboardType";
const NSPasteboardType NSPasteboardTypeURL = @"public.url";
const NSPasteboardType NSPasteboardTypeColor = @"NSColorPboardType";
const NSPasteboardType NSPasteboardTypeFileURL = @"public.file-url";
const NSPasteboardType NSPasteboardTypeMultipleTextSelection = @"com.apple.cocoa.pasteboard.multiple-text-selection";

const NSPasteboardType NSColorPboardType = @"NSColorPboardType";
const NSPasteboardType NSFileContentsPboardType = @"NSFileContentsPboardType";
const NSPasteboardType NSFilenamesPboardType = @"NSFilenamesPboardType";
const NSPasteboardType NSFontPboardType = @"NSFontPboardType";
const NSPasteboardType NSPDFPboardType = @"NSPDFPboardType";
const NSPasteboardType NSPICTPboardType = @"NSPICTPboardType";
const NSPasteboardType NSPostScriptPboardType = @"NSPostScriptPboardType";
const NSPasteboardType NSRTFDPboardType = @"NSRTFDPboardType";
const NSPasteboardType NSRTFPboardType = @"NSRTFPboardType";
const NSPasteboardType NSRulerPboardType = @"NSRulerPboardType";
const NSPasteboardType NSStringPboardType = @"NSStringPboardType";
const NSPasteboardType NSTabularTextPboardType = @"NSTabularTextPboardType";
const NSPasteboardType NSTIFFPboardType = @"NSTIFFPboardType";
const NSPasteboardType NSURLPboardType = @"NSURLPboardType";
const NSPasteboardType NSHTMLPboardType = @"Apple HTML pasteboard type";
const NSPasteboardType NSVCardPboardType = @"NSVCardPboardType";
const NSPasteboardType NSInkTextPboardType = @"Apple InkText pasteboard type";
const NSPasteboardType NSMultipleTextSelectionPboardType = @"Apple multiple text selection pasteboard type";

const NSPasteboardType NSFilesPromisePboardType =
        @"Apple files promise pasteboard type";

const NSPasteboardName NSPasteboardNameDrag = @"Apple CFPasteboard drag";
NSString *const NSPasteboardURLReadingFileURLsOnlyKey =
        @"NSPasteboardURLReadingFileURLsOnlyKey";

const NSPasteboardName NSDragPboard = @"NSDragPboard";
const NSPasteboardName NSFindPboard = @"NSFindPboard";
const NSPasteboardName NSFontPboard = @"NSFontPboard";
const NSPasteboardName NSGeneralPboard = @"NSGeneralPboard";
const NSPasteboardName NSRulerPboard = @"NSRulerPboard";

const NSPasteboardName NSPasteboardNameFind = @"Apple CFPasteboard find";
const NSPasteboardName NSPasteboardNameFont = @"Apple CFPasteboard font";
const NSPasteboardName NSPasteboardNameGeneral = @"Apple CFPasteboard general";

const NSPasteboardReadingOptionKey
        NSPasteboardURLReadingContentsConformToTypesKey =
                @"NSPasteboardURLReadingContentsConformToTypesKey";

// Legacy Cocotron type names are not UTIs; conformance needs the UTI spelling.
static NSString *UTIForPasteboardType(NSString *type) {
    static NSDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      map = [@{
          NSStringPboardType : @"public.utf8-plain-text",
          NSTabularTextPboardType : @"public.utf8-tab-separated-values-text",
          NSRTFPboardType : @"public.rtf",
          NSRTFDPboardType : @"com.apple.rtfd",
          NSPasteboardTypeHTML : @"public.html",
          NSHTMLPboardType : @"public.html",
          NSPDFPboardType : @"com.adobe.pdf",
          NSTIFFPboardType : @"public.tiff",
          NSURLPboardType : @"public.url",
          NSFilenamesPboardType : NSPasteboardTypeFileURL,
      } retain];
    });
    return [map objectForKey: type] ?: type;
}

static BOOL PasteboardTypeConformsTo(NSString *type, NSString *uti) {
    type = UTIForPasteboardType(type);
    uti = UTIForPasteboardType(uti);
    if ([type isEqualToString: uti])
        return YES;
    return [[NSWorkspace sharedWorkspace] type: type conformsToType: uti];
}

// Logs once per class so a handler that polls does not flood the log.
static void LogUnsupportedOnce(Class cls, NSString *action) {
    static NSMutableSet *warned = nil;
    @synchronized([NSPasteboard class]) {
        if (warned == nil)
            warned = [NSMutableSet new];
        NSString *key = [action stringByAppendingString: NSStringFromClass(cls)];
        if ([warned containsObject: key])
            return;
        [warned addObject: key];
    }
    NSLog(@"NSPasteboard: %@ %@ objects is not supported; skipping them",
          action, NSStringFromClass(cls));
}

@implementation NSPasteboard

+ (NSPasteboard *) generalPasteboard {
    return [self pasteboardWithName: NSGeneralPboard];
}

+ (NSPasteboard *) pasteboardWithName: (NSPasteboardName) name {
    return [[NSDisplay currentDisplay] pasteboardWithName: name];
}

- (NSPasteboardName) name {
    NSUnimplementedMethod();
    return nil;
}

- (NSInteger) changeCount {
    NSUnimplementedMethod();
    return 0;
}

- (NSInteger) clearContents {
    NSUnimplementedMethod();
    return 0;
}

- (oneway void) releaseGlobally {
    NSUnimplementedMethod();
}

- (NSArray<NSPasteboardType> *) types {
    NSUnimplementedMethod();
    return nil;
}

- (NSPasteboardType) availableTypeFromArray: (NSArray<NSPasteboardType> *) types
{
    NSArray<NSPasteboardType> *available = [self types];
    for (NSPasteboardType type in types) {
        if ([available containsObject: type]) {
            return type;
        }
    }
    return nil;
}

- (NSData *) dataForType: (NSPasteboardType) type {
    NSUnimplementedMethod();
    return nil;
}

- (NSString *) stringForType: (NSPasteboardType) type {
    NSData *data = [self dataForType: type];

    return [[[NSString alloc] initWithData: data
                                  encoding: NSUnicodeStringEncoding]
            autorelease];
}

- (id) propertyListForType: (NSPasteboardType) type {
    NSData *data = [self dataForType: type];
    NSString *errorDesc = nil;
    id plist = [NSPropertyListSerialization
            propertyListFromData: data
                mutabilityOption: NSPropertyListImmutable
                          format: NULL
                errorDescription: &errorDesc];
    if (plist && errorDesc == nil) {
        return plist;
    }
    NSLog(@"propertyListForType: produced error: %@", errorDesc);
    return nil;
}

- (NSInteger) declareTypes: (NSArray<NSPasteboardType> *) types
                     owner: (id<NSPasteboardTypeOwner>) owner
{
    NSUnimplementedMethod();
    return 0;
}

- (NSInteger) addTypes: (NSArray<NSPasteboardType> *) types
                 owner: (id<NSPasteboardTypeOwner>) owner
{
    NSUnimplementedMethod();
    return 0;
}

- (BOOL) setData: (NSData *) data forType: (NSPasteboardType) type {
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) setString: (NSString *) string forType: (NSPasteboardType) type {
    NSData *data = [string dataUsingEncoding: NSUnicodeStringEncoding];
    return [self setData: data forType: type];
}

- (BOOL) setPropertyList: (id) plist forType: (NSPasteboardType) type {
    NSString *errorDesc = nil;
    NSData *data = [NSPropertyListSerialization
            dataFromPropertyList: plist
                          format: NSPropertyListXMLFormat_v1_0
                errorDescription: &errorDesc];
    if (data && errorDesc == nil) {
        return [self setData: data forType: type];
    }
    NSLog(@"setPropertyList:forType: produced error: %@", errorDesc);
    return NO;
}

// URL types carry UTF-8 text on the wire; -stringForType: decodes other types
// as UTF-16 in the backends, so decode the raw bytes here.
- (NSURL *) _urlForType: (NSPasteboardType) type {
    NSData *data = [self dataForType: type];
    NSString *string =
            data ? [[[NSString alloc] initWithData: data
                                          encoding: NSUTF8StringEncoding]
                           autorelease]
                 : nil;
    return [string length] ? [NSURL URLWithString: string] : nil;
}

// Entries that are not strings come from the other process; ignore them.
- (NSArray *) _fileURLs {
    NSArray *types = [self types];
    NSMutableArray *urls = [NSMutableArray array];
    if ([types containsObject: NSFilenamesPboardType]) {
        id paths = [self propertyListForType: NSFilenamesPboardType];
        for (id path in [paths isKindOfClass: [NSArray class]] ? paths : nil)
            if ([path isKindOfClass: [NSString class]] && [path length])
                [urls addObject: [NSURL fileURLWithPath: path]];
    } else if ([types containsObject: NSPasteboardTypeFileURL]) {
        NSURL *url = [self _urlForType: NSPasteboardTypeFileURL];
        if ([url isFileURL])
            [urls addObject: url];
    }
    return urls;
}

- (BOOL) _fileURL: (NSURL *) url conformsToAnyOf: (NSArray *) utis {
    NSString *extension = [[url path] pathExtension];
    if ([extension length] == 0)
        return NO;
    NSString *type =
            [[UTType typeWithFilenameExtension: extension] identifier];
    for (NSString *uti in utis)
        if (type && PasteboardTypeConformsTo(type, uti))
            return YES;
    return NO;
}

// Builds an object of exactly cls from the non-file item, or returns nil when
// the pasteboard cannot supply one.
- (id) _readContentOfClass: (Class) cls options: (NSDictionary *) options {
    NSArray *types = [self types];

    if (cls == [NSString class]) {
        if ([types containsObject: NSStringPboardType])
            return [self stringForType: NSStringPboardType];
    } else if (cls == [NSURL class]) {
        if (![[options objectForKey: NSPasteboardURLReadingFileURLsOnlyKey]
                    boolValue] &&
            [options objectForKey:
                             NSPasteboardURLReadingContentsConformToTypesKey] == nil &&
            [types containsObject: NSPasteboardTypeURL])
            return [self _urlForType: NSPasteboardTypeURL];
    } else if (cls == [NSAttributedString class]) {
        if ([types containsObject: NSRTFPboardType]) {
            NSData *rtf = [self dataForType: NSRTFPboardType];
            NSAttributedString *string = [[[NSAttributedString alloc]
                    initWithRTF: rtf
             documentAttributes: NULL] autorelease];
            if (string)
                return string;
        }
        if ([types containsObject: NSStringPboardType]) {
            NSString *plain = [self stringForType: NSStringPboardType];
            return plain ? [[[NSAttributedString alloc] initWithString: plain]
                                   autorelease]
                         : nil;
        }
    } else if (cls == [NSImage class]) {
        if ([NSImage canInitWithPasteboard: self])
            return [[[NSImage alloc] initWithPasteboard: self] autorelease];
    } else {
        // NSPasteboardItem, NSColor, NSSound and NSPasteboardReading
        // implementations are not available here; skip the class like a class
        // with no matching data rather than failing the caller's handler.
        LogUnsupportedOnce(cls, @"reading");
    }
    return nil;
}

- (BOOL) canReadObjectForClasses: (NSArray<Class> *) classArray
                         options: (nullable NSDictionary<NSPasteboardReadingOptionKey, id> *)
                                          options
{
    return [[self readObjectsForClasses: classArray options: options] count] >
           0;
}

- (nullable NSArray *)
        readObjectsForClasses: (NSArray<Class> *) classArray
                      options: (nullable NSDictionary<NSPasteboardReadingOptionKey, id> *)
                                       options
{
    NSArray *conformTo = [options
            objectForKey: NSPasteboardURLReadingContentsConformToTypesKey];
    BOOL wantsURL = NO;
    for (Class cls in classArray)
        wantsURL = wantsURL || cls == [NSURL class];

    NSMutableArray *objects = [NSMutableArray array];
    NSArray *files = wantsURL ? [self _fileURLs] : @[];
    // Each file is its own item, readable only as a file NSURL.
    for (NSURL *url in files)
        if (conformTo == nil || [self _fileURL: url conformsToAnyOf: conformTo])
            [objects addObject: url];
    // The remaining content is one item; the first class that reads it wins.
    // Files filtered out by conformance do not fall through to it.
    if ([files count] == 0) {
        for (Class cls in classArray) {
            id object = [self _readContentOfClass: cls options: options];
            if (object != nil) {
                [objects addObject: object];
                break;
            }
        }
    }
    return [objects count] ? objects : nil;
}

- (BOOL) canReadItemWithDataConformingToTypes: (NSArray<NSString *> *) types {
    for (NSPasteboardType have in [self types])
        for (NSString *want in types)
            if (PasteboardTypeConformsTo(have, want))
                return YES;
    return NO;
}

// Types whose payload is UTF-8 text on the wire (and in the backends'
// -stringForType:/-dataForType: for NSStringPboardType); a plist string for
// them must not go through -setString:forType:, which may encode UTF-16.
static BOOL IsUTF8TextType(NSString *type) {
    return [type isEqual: NSStringPboardType] ||
           [type isEqual: NSPasteboardTypeURL] ||
           [type isEqual: NSPasteboardTypeFileURL];
}

static NSData *UTF8Data(NSString *string) {
    return [string dataUsingEncoding: NSUTF8StringEncoding];
}

- (BOOL) _setPropertyList: (id) plist forType: (NSPasteboardType) type {
    if ([plist isKindOfClass: [NSData class]])
        return [self setData: plist forType: type];
    if ([plist isKindOfClass: [NSString class]])
        return IsUTF8TextType(type)
                       ? [self setData: UTF8Data(plist) forType: type]
                       : [self setString: plist forType: type];
    if (plist != nil &&
        [NSPropertyListSerialization propertyList: plist
                                 isValidForFormat: NSPropertyListXMLFormat_v1_0])
        return [self setPropertyList: plist forType: type];
    return NO;
}

// (type, property list) pairs for the classes this tree can serialize itself,
// or nil when the object is not one of them.
- (NSArray *) _representationsOfObject: (id) object {
    NSMutableArray *pairs = [NSMutableArray array];
    if ([object isKindOfClass: [NSString class]]) {
        [pairs addObject: @[ NSStringPboardType, UTF8Data(object) ]];
    } else if ([object isKindOfClass: [NSURL class]]) {
        [pairs addObject: @[ NSPasteboardTypeURL,
                             UTF8Data([object absoluteString]) ]];
    } else if ([object isKindOfClass: [NSAttributedString class]]) {
        NSData *rtf = [object RTFFromRange: NSMakeRange(0, [object length])
                        documentAttributes: nil];
        if (rtf != nil)
            [pairs addObject: @[ NSRTFPboardType, rtf ]];
        [pairs addObject: @[ NSStringPboardType,
                             UTF8Data([object string]) ]];
    } else if ([object isKindOfClass: [NSImage class]]) {
        NSData *tiff = [object TIFFRepresentation];
        if (tiff != nil)
            [pairs addObject: @[ NSTIFFPboardType, tiff ]];
    } else {
        return nil;
    }
    return pairs;
}

// The pasteboard holds a single item, so the objects share one set of types:
// the first object to supply a type wins and later ones supply only the types
// still free (so several strings return NO and keep only the first, where
// Apple writes one item per object and returns YES; a known divergence). File URLs are merged into one NSFilenamesPboardType list. An
// object counts as written when at least one of its types was stored.
// Promised writing is not supported: NSPasteboardWritingPromised is ignored
// and the data is requested immediately.
- (BOOL) writeObjects: (NSArray *) objects {
    if (objects == nil)
        return NO;
    NSMutableSet *claimed = [NSMutableSet set];
    NSMutableArray *filePaths = [NSMutableArray array];
    NSURL *firstFile = nil;
    BOOL allWritten = YES;

    for (id object in objects) {
        NSArray *pairs = nil;
        if ([object conformsToProtocol: @protocol(NSPasteboardWriting)]) {
            NSMutableArray *provided = [NSMutableArray array];
            for (NSPasteboardType type in
                 [object writableTypesForPasteboard: self]) {
                id plist = [object pasteboardPropertyListForType: type];
                if (plist != nil)
                    [provided addObject: @[ type, plist ]];
            }
            pairs = provided;
        } else if ([object isKindOfClass: [NSURL class]] &&
                   [object isFileURL]) {
            NSString *path = [object path];
            if ([path length] == 0)
                allWritten = NO;
            else {
                [filePaths addObject: path];
                firstFile = firstFile ?: object;
            }
            continue;
        } else {
            pairs = [self _representationsOfObject: object];
            if (pairs == nil)
                LogUnsupportedOnce([object class], @"writing");
        }

        BOOL wrote = NO;
        for (NSArray *pair in pairs) {
            if ([claimed containsObject: pair[0]])
                continue;
            if ([self _setPropertyList: pair[1] forType: pair[0]]) {
                [claimed addObject: pair[0]];
                wrote = YES;
            }
        }
        allWritten = allWritten && wrote;
    }

    if (firstFile != nil) {
        BOOL wrote = NO;
        if (![claimed containsObject: NSPasteboardTypeFileURL])
            wrote = [self setData: UTF8Data([firstFile absoluteString])
                          forType: NSPasteboardTypeFileURL];
        if (![claimed containsObject: NSFilenamesPboardType])
            wrote = [self setPropertyList: filePaths
                                  forType: NSFilenamesPboardType] || wrote;
        allWritten = allWritten && wrote;
    }
    return allWritten;
}

@end
