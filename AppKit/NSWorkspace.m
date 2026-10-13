/* Copyright (c) 2006-2007 Christopher J. W. Lloyd <cjwl@objc.net>

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
#import <AppKit/NSWorkspace.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <unistd.h>

NSString *const NSWorkspaceApplicationKey = @"NSWorkspaceApplicationKey";

/* darling-lol: opening a URL from the guest.
 *
 * LaunchServices cannot start a Linux browser from inside the prefix, and Electron's
 * shell.openExternal() uses -openURL:configuration:completionHandler: (macOS 10.15) with an
 * NSWorkspaceOpenConfiguration, neither of which existed: the unrecognized selector crashed the
 * client ("Can't sign in?", links, ...). Hand the URL to the host through a spool directory in
 * the shared /private/tmp. The legacy tools/riot-open-url-bridge.py can drain it, but is excluded
 * from normal launches because it also installs a client inspector hook.
 * Only http, https and mailto URLs are queued. */
@interface NSWorkspaceOpenConfiguration () {
    BOOL _activates, _hides, _hidesOthers, _addsToRecentItems, _createsNewApplicationInstance;
    BOOL _allowsRunningApplicationSubstitution, _forPrinting, _promptsUserIfNeeded, _requiresUniversalLinks;
    NSAppleEventDescriptor *_appleEvent;
    NSArray *_arguments;
    NSDictionary *_environment;
    cpu_type_t _architecture;
}
@end

@implementation NSWorkspaceOpenConfiguration
@synthesize activates = _activates, hides = _hides, hidesOthers = _hidesOthers;
@synthesize addsToRecentItems = _addsToRecentItems, createsNewApplicationInstance = _createsNewApplicationInstance;
@synthesize allowsRunningApplicationSubstitution = _allowsRunningApplicationSubstitution;
@synthesize forPrinting = _forPrinting, promptsUserIfNeeded = _promptsUserIfNeeded;
@synthesize requiresUniversalLinks = _requiresUniversalLinks;
@synthesize appleEvent = _appleEvent, arguments = _arguments, environment = _environment;
@synthesize architecture = _architecture;
+ (instancetype) configuration {
    NSWorkspaceOpenConfiguration *c = [[[self alloc] init] autorelease];
    c->_activates = YES;
    c->_addsToRecentItems = YES;
    c->_allowsRunningApplicationSubstitution = YES;
    return c;
}
- (id) copyWithZone: (NSZone *) zone {
    NSWorkspaceOpenConfiguration *c = [[[self class] allocWithZone: zone] init];
    c->_activates = _activates; c->_hides = _hides; c->_hidesOthers = _hidesOthers;
    c->_addsToRecentItems = _addsToRecentItems;
    c->_createsNewApplicationInstance = _createsNewApplicationInstance;
    c->_allowsRunningApplicationSubstitution = _allowsRunningApplicationSubstitution;
    c->_forPrinting = _forPrinting; c->_promptsUserIfNeeded = _promptsUserIfNeeded;
    c->_requiresUniversalLinks = _requiresUniversalLinks; c->_architecture = _architecture;
    c->_appleEvent = [_appleEvent retain];
    c->_arguments = [_arguments copy]; c->_environment = [_environment copy];
    return c;
}
- (void) dealloc {
    [_appleEvent release];
    [_arguments release];
    [_environment release];
    [super dealloc];
}
@end

BOOL RCLOLOpenURLViaHost(NSURL *url) {
    NSString *scheme = [[url scheme] lowercaseString];
    if (![scheme isEqualToString: @"http"] && ![scheme isEqualToString: @"https"] &&
        ![scheme isEqualToString: @"mailto"])
        return NO;
    NSString *absolute = [url absoluteString];
    if ([absolute length] == 0 || [absolute length] > 4096)
        return NO;
    NSString *directory = @"/private/tmp/rclol-open";
    [[NSFileManager defaultManager] createDirectoryAtPath: directory
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: NULL];
    static unsigned sequence = 0;
    NSString *path = [NSString stringWithFormat: @"%@/%d-%u-%llu.url", directory, (int) getpid(),
                      ++sequence, (unsigned long long) (CFAbsoluteTimeGetCurrent() * 1000)];
    NSString *temporary = [path stringByAppendingString: @".part"];
    if (![absolute writeToFile: temporary atomically: NO encoding: NSUTF8StringEncoding error: NULL])
        return NO;
    return rename([temporary fileSystemRepresentation], [path fileSystemRepresentation]) == 0;
}


NSString *const NSWorkspaceWillPowerOffNotification =
        @"NSWorkspaceWillPowerOffNotification";

NSString *const NSWorkspaceRecycleOperation = @"NSWorkspaceRecycleOperation";

NSString *const NSWorkspaceLaunchConfigurationAppleEvent =
        @"NSWorkspaceLaunchConfigurationAppleEvent";
NSString *const NSWorkspaceLaunchConfigurationArguments =
        @"NSWorkspaceLaunchConfigurationArguments";
NSString *const NSWorkspaceLaunchConfigurationEnvironment =
        @"NSWorkspaceLaunchConfigurationEnvironment";
NSString *const NSWorkspaceLaunchConfigurationArchitecture =
        @"NSWorkspaceLaunchConfigurationArchitecture";

NSString *const NSWorkspaceActiveSpaceDidChangeNotification =
        @"NSWorkspaceActiveSpaceDidChangeNotification";
const NSNotificationName NSWorkspaceDidDeactivateApplicationNotification =
        @"NSWorkspaceDidDeactivateApplicationNotification";
const NSNotificationName NSWorkspaceDidWakeNotification = 
        @"NSWorkspaceDidWakeNotification";
NSString *const NSWorkspaceDidLaunchApplicationNotification =
        @"NSWorkspaceDidLaunchApplicationNotification";
NSString *const NSWorkspaceDidTerminateApplicationNotification =
        @"NSWorkspaceDidTerminateApplicationNotification";
const NSNotificationName NSWorkspaceScreensDidSleepNotification =
        @"NSWorkspaceScreensDidSleepNotification";
const NSNotificationName NSWorkspaceScreensDidWakeNotification =
        @"NSWorkspaceScreensDidWakeNotification";
const NSNotificationName NSWorkspaceWillSleepNotification =
        @"NSWorkspaceWillSleepNotification";
const NSNotificationName NSWorkspaceSessionDidBecomeActiveNotification =
        @"NSWorkspaceSessionDidBecomeActiveNotification";
const NSNotificationName NSWorkspaceSessionDidResignActiveNotification =
        @"NSWorkspaceSessionDidResignActiveNotification";
NSNotificationName const NSWorkspaceDidActivateApplicationNotification = @"NSWorkspaceDidActivateApplicationNotification";

const NSNotificationName
        NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification =
                @"NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification";

NSNotificationName NSWorkspaceDidMountNotification = @"NSWorkspaceDidMountNotification";
NSNotificationName NSWorkspaceDidUnmountNotification = @"NSWorkspaceDidUnmountNotification";
NSNotificationName NSWorkspaceWillUnmountNotification = @"NSWorkspaceWillUnmountNotification";

@implementation NSWorkspace

+ (NSWorkspace *) sharedWorkspace {
    return NSThreadSharedInstance(@"NSWorkspace");
}

- init {
    _notificationCenter = [[NSNotificationCenter alloc] init];
    return self;
}

- (NSNotificationCenter *) notificationCenter {
    return _notificationCenter;
}

- (NSImage *) iconForFile: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSImage *) iconForFiles: (NSArray *) array {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSImage *) iconForFileType: (NSString *) type {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) localizedDescriptionForType: (NSString *) type {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) filenameExtension: (NSString *) extension
            isValidForType: (NSString *) type
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) preferredFilenameExtensionForType: (NSString *) type {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) type: (NSString *) type conformsToType: (NSString *) conformsToType {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) typeOfFile: (NSString *) path error: (NSError **) error {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openFile: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openFile: (NSString *) path withApplication: (NSString *) application {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openTempFile: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openFile: (NSString *) path
        fromImage: (NSImage *) image
               at: (NSPoint) point
           inView: (NSView *) view
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openFile: (NSString *) path
        withApplication: (NSString *) application
          andDeactivate: (BOOL) deactivate
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openURL: (NSURL *) url {
    return RCLOLOpenURLViaHost(url);
}

- (void) openURL: (NSURL *) url
        configuration: (NSWorkspaceOpenConfiguration *) configuration
        completionHandler: (void (^)(id application, NSError *error)) completionHandler
{
    BOOL opened = [self openURL: url];
    if (completionHandler != NULL) {
        NSError *error = nil;
        if (!opened)
            error = [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, error);
        });
    }
}

- (BOOL) selectFile: (NSString *) path
        inFileViewerRootedAtPath: (NSString *) rootedAtPath
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) slideImage: (NSImage *) image from: (NSPoint) from to: (NSPoint) to {
    NSInvalidAbstractInvocation();
}

- (BOOL) performFileOperation: (NSString *) operation
                       source: (NSString *) source
                  destination: (NSString *) destination
                        files: (NSArray *) files
                          tag: (NSInteger *) tag
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) getFileSystemInfoForPath: (NSString *) path
                      isRemovable: (BOOL *) isRemovable
                       isWritable: (BOOL *) isWritable
                    isUnmountable: (BOOL *) isUnmountable
                      description: (NSString **) description
                             type: (NSString **) type
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) getInfoForFile: (NSString *) path
            application: (NSString **) application
                   type: (NSString **) type
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) checkForRemovableMedia {
    NSInvalidAbstractInvocation();
}

- (NSArray *) mountNewRemovableMedia {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSArray *) mountedRemovableMedia {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSArray *) mountedLocalVolumePaths {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) unmountAndEjectDeviceAtPath: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) fileSystemChanged {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) userDefaultsChanged {
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) noteFileSystemChanged {
    NSInvalidAbstractInvocation();
}

- (void) noteFileSystemChanged: (NSString *) path {
    NSInvalidAbstractInvocation();
}

- (void) noteUserDefaultsChanged {
    NSInvalidAbstractInvocation();
}

- (BOOL) isFilePackageAtPath: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) absolutePathForAppBundleWithIdentifier: (NSString *) identifier {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) pathForApplication: (NSString *) application {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSArray *) launchedApplications {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSArray *) runningApplications {
    // NSInvalidAbstractInvocation();
    return @[];
}

- (BOOL) launchApplication: (NSString *) application {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) launchApplication: (NSString *) application
                  showIcon: (BOOL) showIcon
                autolaunch: (BOOL) autolaunch
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) findApplications {
    NSInvalidAbstractInvocation();
}

- (NSDictionary *) activeApplication {
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) hideOtherApplications {
    NSInvalidAbstractInvocation();
}

- (NSInteger) extendPowerOffBy: (NSInteger) milliseconds {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) fullPathForApplication: (NSString *) appName {
    NSInvalidAbstractInvocation();
    return nil;
}

@end

@implementation NSWorkspace (CocotronAdditions)

- (BOOL) isFileHiddenAtPath: (NSString *) path {
    return NO;
}

@end
