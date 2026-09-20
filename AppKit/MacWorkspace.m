#import "MacWorkspace.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSRaise.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#include <LaunchServices/LaunchServices.h>
#include <string.h>

static NSCache *_workspaceIconCache;

static NSCache *WorkspaceIconCache(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        _workspaceIconCache = [[NSCache alloc] init];
    });
    return _workspaceIconCache;
}

static NSImage *ImageFromIconFile(NSString *file) {
    NSImage *icon = nil;
    @try {
        icon = [[[NSImage alloc] initWithContentsOfFile: file] autorelease];
    } @catch (NSException *exception) {
        icon = nil;
    }
    if (icon != nil && (icon.size.width <= 0.0 || icon.size.height <= 0.0))
        icon = nil;
    return icon;
}

static NSImage *ImageFromIcnsFile(NSString *file) {
    NSData *data = [NSData dataWithContentsOfFile: file];
    if (data == nil)
        return nil;

    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSUInteger length = [data length];
    uint32_t declaredLength = (length >= 8)
            ? (((uint32_t)bytes[4] << 24) | ((uint32_t)bytes[5] << 16) |
               ((uint32_t)bytes[6] << 8) | bytes[7])
            : 0;

    if (length < 8 || memcmp(bytes, "icns", 4) != 0 ||
        declaredLength < 8 || declaredLength > length)
        return nil;

    NSImage *best = nil;
    CGFloat bestArea = 0.0;
    NSUInteger offset = 8;
    while (offset + 8 <= declaredLength) {
        uint32_t chunkLength = ((uint32_t)bytes[offset + 4] << 24) |
                ((uint32_t)bytes[offset + 5] << 16) |
                ((uint32_t)bytes[offset + 6] << 8) | bytes[offset + 7];
        if (chunkLength < 8 || chunkLength > declaredLength - offset)
            break;

        BOOL pngChunk = (memcmp(bytes + offset, "ic13", 4) == 0 ||
                         memcmp(bytes + offset, "ic12", 4) == 0 ||
                         memcmp(bytes + offset, "ic11", 4) == 0 ||
                         memcmp(bytes + offset, "ic10", 4) == 0 ||
                         memcmp(bytes + offset, "ic09", 4) == 0 ||
                         memcmp(bytes + offset, "ic08", 4) == 0 ||
                         memcmp(bytes + offset, "ic07", 4) == 0);
        if (pngChunk && chunkLength > 8) {
            NSData *payload =
                    [data subdataWithRange: NSMakeRange(offset + 8, chunkLength - 8)];
            if (payload.length >= 8 &&
                memcmp([payload bytes], "\x89PNG\r\n\x1a\n", 8) == 0) {
                NSImage *candidate = nil;
                @try {
                    candidate = [[[NSImage alloc] initWithData: payload] autorelease];
                } @catch (NSException *exception) {
                    candidate = nil;
                }
                CGFloat area = (candidate != nil)
                        ? candidate.size.width * candidate.size.height : 0.0;
                if (candidate != nil && area > bestArea) {
                    best = candidate;
                    bestArea = area;
                }
            }
        }
        offset += chunkLength;
    }
    return best;
}

@implementation NSWorkspace (macos)

+ allocWithZone: (NSZone *) zone {
    return NSAllocateObject([MacWorkspace class], 0, NULL);
}

@end

@implementation MacWorkspace

- (NSImage *) iconForFile: (NSString *) path {
    if (path == nil || [path length] == 0)
        return nil;

    NSImage *cached = [WorkspaceIconCache() objectForKey: path];
    if (cached != nil)
        return cached;

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &isDirectory] ||
        !isDirectory)
        return nil;

    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
            [path stringByAppendingPathComponent: @"Contents/Info.plist"]];
    if (info == nil)
        return nil;

    NSMutableArray *names = [NSMutableArray array];
    id value = [info objectForKey: @"CFBundleIconName"];
    if ([value isKindOfClass: [NSString class]])
        [names addObject: value];
    value = [info objectForKey: @"CFBundleIconFile"];
    if ([value isKindOfClass: [NSString class]] && ![names containsObject: value])
        [names addObject: value];
    value = [info objectForKey: @"CFBundleIconFiles"];
    if ([value isKindOfClass: [NSArray class]])
        for (id item in value)
            if ([item isKindOfClass: [NSString class]])
                [names addObject: item];

    NSString *resources =
            [path stringByAppendingPathComponent: @"Contents/Resources"];
    for (NSString *name in names) {
        NSString *candidate = ([name pathExtension].length > 0)
                ? name : [name stringByAppendingPathExtension: @"icns"];
        NSString *file = [resources stringByAppendingPathComponent: candidate];
        NSImage *icon = ImageFromIconFile(file);
        if (icon == nil)
            icon = ImageFromIcnsFile(file);
        if (icon != nil) {
            [WorkspaceIconCache() setObject: icon forKey: path];
            return icon;
        }
    }

    return nil;
}

- (NSImage *) iconForFiles: (NSArray *) array {
    NSUnimplementedMethod();
    return NULL;
}

- (NSImage *) iconForFileType: (NSString *) type {
    // TODO: call GetIconRefFromTypeInfo()
    NSUnimplementedMethod();
    return NULL;
}

- (NSString *) localizedDescriptionForType: (NSString *) type {
    // TODO: call UTTypeCopyDescription()
    NSUnimplementedMethod();
    return NULL;
}

- (BOOL) filenameExtension: (NSString *) extension
            isValidForType: (NSString *) type
{
    // TODO: call UTTypeCreateAllIdentifiersForTag
    NSUnimplementedMethod();
    return NO;
}

- (NSString *) preferredFilenameExtensionForType: (NSString *) type {
    // TODO: call UTTypeCopyPreferredTagWithClass(kUTTagClassFilenameExtension)
    NSUnimplementedMethod();
    return NULL;
}

- (BOOL) type: (NSString *) type conformsToType: (NSString *) conformsToType {
    // TODO: call UTTypeConformsTo()
    NSUnimplementedMethod();
    return NO;
}

- (NSString *) typeOfFile: (NSString *) path error: (NSError **) error {
    // TODO: call LSCopyItemAttribute(kLSItemContentType)
    NSUnimplementedMethod();
    return NULL;
}

- (BOOL) openFile: (NSString *) path {
    return [self openFile: path withApplication: nil];
}

- (BOOL) openFile: (NSString *) path withApplication: (NSString *) application {
    return [self openFile: path
            withApplication: application
              andDeactivate: YES];
}

- (BOOL) openTempFile: (NSString *) path {
    return [self openFile: path withApplication: nil andDeactivate: YES];
}

- (BOOL) openFile: (NSString *) path
        fromImage: (NSImage *) image
               at: (NSPoint) point
           inView: (NSView *) view
{
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) openFile: (NSString *) path
        withApplication: (NSString *) application
          andDeactivate: (BOOL) deactivate
{
    /* LaunchServices is not available in the Darling guest yet.  The
       Applications viewer nevertheless has a real bundle path, so launch
       its CFBundleExecutable directly.  The inherited environment carries
       the reviewed display backend; arm64e app code needs pointer
       authentication disabled, so force DARLING_DISABLE_PTRAUTH=1 here
       (same as the homebrew-actions launcher does per every launch). */
    NSString *bundlePath = application;
    if (!bundlePath && path && [path hasSuffix: @".app"])
        bundlePath = path;
    if (!bundlePath)
        return NO;

    NSString *plistPath = [bundlePath stringByAppendingPathComponent: @"Contents/Info.plist"];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile: plistPath];
    NSString *executable = [plist objectForKey: @"CFBundleExecutable"];
    if (![executable isKindOfClass: [NSString class]] || [executable length] == 0)
        executable = [bundlePath lastPathComponent];
    if ([executable hasSuffix: @".app"])
        executable = [executable substringToIndex: [executable length] - 4];

    NSString *launchPath = [bundlePath stringByAppendingPathComponent:
        [NSString stringWithFormat: @"Contents/MacOS/%@", executable]];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath: launchPath isDirectory: &isDirectory] || isDirectory)
        return NO;

    NSMutableDictionary *environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
    [environment setObject: @"1" forKey: @"DARLING_DISABLE_PTRAUTH"];
    NSLog(@"NSWorkspace launch argv=[%@] bundle=%@ backend=%@ wayland=%@ display=%@ pac=%@",
          launchPath, bundlePath,
          [environment objectForKey: @"DARLING_APPKIT_BACKEND"],
          [environment objectForKey: @"WAYLAND_DISPLAY"],
          [environment objectForKey: @"DISPLAY"],
          [environment objectForKey: @"DARLING_DISABLE_PTRAUTH"]);

    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: launchPath];
    [task setArguments: @[]];
    [task setEnvironment: environment];
    [task setCurrentDirectoryPath: bundlePath];
    [task setStandardError: [NSFileHandle fileHandleWithStandardError]];
    [task setStandardOutput: [NSFileHandle fileHandleWithStandardOutput]];
    NSError *launchError = nil;
    if (![task launchAndReturnError: &launchError]) {
        NSLog(@"NSWorkspace launch failed executable=%@ error=%@", launchPath, launchError);
        return NO;
    }
    NSLog(@"NSWorkspace launch started executable=%@ pid=%d", launchPath, [task processIdentifier]);
    [task setTerminationHandler: ^(NSTask *finished) {
        NSLog(@"NSWorkspace child terminated executable=%@ pid=%d status=%d reason=%ld",
              launchPath, [finished processIdentifier], [finished terminationStatus],
              (long)[finished terminationReason]);
    }];
    return YES;
}

- (BOOL) openURL: (NSURL *) url {
    // TODO: Call LSOpenFromURLSpec()
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) selectFile: (NSString *) path
        inFileViewerRootedAtPath: (NSString *) rootedAtPath
{
    // TODO: call activateFileViewerSelectingURLs
    NSUnimplementedMethod();
    return NO;
}

- (void) slideImage: (NSImage *) image from: (NSPoint) from to: (NSPoint) to {
}

- (BOOL) performFileOperation: (NSString *) operation
                       source: (NSString *) source
                  destination: (NSString *) destination
                        files: (NSArray *) files
                          tag: (NSInteger *) tag
{
    NSUnimplementedMethod();
}

- (BOOL) getFileSystemInfoForPath: (NSString *) path
                      isRemovable: (BOOL *) isRemovable
                       isWritable: (BOOL *) isWritable
                    isUnmountable: (BOOL *) isUnmountable
                      description: (NSString **) description
                             type: (NSString **) type
{
    if (!path)
        return NO;

    // TODO: call statfs() to get filesystem information
    // Use DiskArbitration for the rest.
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) getInfoForFile: (NSString *) path
            application: (NSString **) application
                   type: (NSString **) type
{
    // TODO: call LSGetApplicationForURL()
    NSUnimplementedMethod();
    return NO;
}

- (void) checkForRemovableMedia {
}

- (NSArray *) mountNewRemovableMedia {
    return [self mountedRemovableMedia];
}

- (NSArray *) mountedRemovableMedia {
    // TODO: call [[NSFileManager defaultManager]
    // mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeIsRemovableKey]
    // options:NSVolumeEnumerationSkipHiddenVolumes]
    NSUnimplementedMethod();
    return @[];
}

- (NSArray *) mountedLocalVolumePaths {
    // TODO: call [[NSFileManager defaultManager]
    // mountedVolumeURLsIncludingResourceValuesForKeys:@[]
    // options:NSVolumeEnumerationSkipHiddenVolumes]
    NSUnimplementedMethod();
    return @[];
}

- (BOOL) unmountAndEjectDeviceAtPath: (NSString *) path {
    // TODO: call FSEjectVolumeSync()
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) fileSystemChanged {
    return NO;
}

- (BOOL) userDefaultsChanged {
    return NO;
}

- (void) noteFileSystemChanged {
    [self noteFileSystemChanged: @"/"];
}

- (void) noteFileSystemChanged: (NSString *) path {
    // TODO: call FNNotifyByPath()
    NSUnimplementedMethod();
}

- (void) noteUserDefaultsChanged {
}

- (BOOL) isFilePackageAtPath: (NSString *) path {
    NSUnimplementedMethod();
}

- (NSString *) absolutePathForAppBundleWithIdentifier: (NSString *) identifier {
    // TODO: call LSFindApplicationForInfo() /
    // LSCopyApplicationURLsForBundleIdentifier()
    NSUnimplementedMethod();
    return NULL;
}

- (NSString *) pathForApplication: (NSString *) application {
    // This method doesn't exist on macOS?!
    return NULL;
}

- (NSArray *) launchedApplications {
    // TODO: call _LSCopyRunningApplicationArray()
    NSUnimplementedMethod();
    return @[];
}

- (NSArray *) runningApplications {
    NSUnimplementedMethod();
    return @[];
}

- (BOOL) launchApplication: (NSString *) application {
    return [self openFile: nil withApplication: application andDeactivate: YES];
}

- (BOOL) launchApplication: (NSString *) application
                  showIcon: (BOOL) showIcon
                autolaunch: (BOOL) autolaunch
{
    return [self openFile: nil withApplication: application andDeactivate: YES];
}

- (void) findApplications {
}

- (NSDictionary *) activeApplication {
    // TODO: call _LSCopyFrontApplication() and _LSCopyApplicationInformation()
    NSUnimplementedMethod();
    return NULL;
}

- (void) hideOtherApplications {
    [NSApp hideOtherApplications: self];
}

- (NSInteger) extendPowerOffBy: (NSInteger) milliseconds {
    return 0;
}

- (BOOL) setIcon: (NSImage *) image
         forFile: (NSString *) fullPath
         options: (NSWorkspaceIconCreationOptions) options
{
    // For directories, we would call the NSFileManager to create a file named
    // "Icon\r" with icon data. For files, we would call
    // FSCreateResFile/FSOpenResFile, FSSetCatalogInfo and other historical
    // functions. But none of these would have effect when viewed from Linux
    // desktop environments...
    NSUnimplementedMethod();
    return NO;
}

- (void) activateFileViewerSelectingURLs: (NSArray<NSURL *> *) fileURLs {
    // TODO: Get the current file viewer app by calling [[NSUserDefaults
    // standardUserDefaults] stringForKey: @"NSFileViewer"] Get its path via
    // [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier]
    // Call [self openFile:withApplication:]
    NSUnimplementedMethod();
}

- (NSURL *) URLForApplicationWithBundleIdentifier: (NSString *) bundleIdentifier
{
    CFURLRef url;
    OSStatus status = LSFindApplicationForInfo(kLSUnknownCreator,
                                               (CFStringRef) bundleIdentifier,
                                               NULL, NULL, &url);

    if (status != noErr)
        return nil;

    return [(NSURL *) url autorelease];
}

- (NSString *) fullPathForApplication: (NSString *) appName {
    // If absolute, return as-is
    if ([appName isAbsolutePath])
        return appName;

    // If it doesn't have an suffix, add .app
    if ([[appName pathExtension] isEqualToString: @""])
        appName = [appName stringByAppendingPathExtension: @"app"];

    CFURLRef url;
    OSStatus status = LSFindApplicationForInfo(
            kLSUnknownCreator, NULL, (CFStringRef) appName, NULL, &url);

    if (status != noErr)
        return nil;

    NSString *path = [(NSURL *) url path];
    CFRelease(url);

    return path;
}

@end
