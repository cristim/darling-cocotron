#import <AppKit/AppKit.h>
#include <CoreServices/CoreServices.h>
#include <stdlib.h>
#include <sys/stat.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static BOOL waitForFile(NSString *path)
{
    for (int i = 0; i < 100; i++)
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
        usleep(100000);
    }
    return NO;
}

// An .app bundle whose executable is a script that writes `marker`.
static NSURL *makeApp(NSString *directory, NSString *marker)
{
    NSString *app = [directory stringByAppendingPathComponent:@"Opener.app"];
    NSString *macOS = [app stringByAppendingPathComponent:@"Contents/MacOS"];
    for (NSString *path in @[ directory, app, [app stringByAppendingPathComponent:@"Contents"], macOS ])
        mkdir([path fileSystemRepresentation], 0755);
    [@{@"CFBundleExecutable" : @"opener", @"CFBundleName" : @"Opener"}
        writeToFile:[app stringByAppendingPathComponent:@"Contents/Info.plist"] atomically:YES];
    NSString *script = [NSString stringWithFormat:@"#!/bin/sh\necho opened >> %@\n", marker];
    NSString *executable = [macOS stringByAppendingPathComponent:@"opener"];
    [script writeToFile:executable atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions : @0755} ofItemAtPath:executable error:NULL];
    return [NSURL fileURLWithPath:app];
}

int main(void)
{
    @autoreleasepool
    {
        NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
        expect(workspace != nil && workspace == [NSWorkspace sharedWorkspace], @"sharedWorkspace class property");

        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"workspace-open-url-%d", getpid()]];
        NSString *marker = [directory stringByAppendingPathComponent:@"marker"];
        NSURL *app = makeApp(directory, marker);

        expect([workspace openURL:app], @"-openURL: launches an .app bundle");
        expect(waitForFile(marker), @"the launched app ran");
        [[NSFileManager defaultManager] removeItemAtPath:marker error:NULL];

        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block NSError *appError = [NSError errorWithDomain:@"unset" code:0 userInfo:nil];
        [workspace openURL:app configuration:[NSWorkspaceOpenConfiguration configuration]
            completionHandler:^(NSRunningApplication *running, NSError *error) {
                appError = [error retain];
                dispatch_semaphore_signal(done);
            }];
        expect(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
               @"completion handler called for the app");
        expect(appError == nil, [NSString stringWithFormat:@"no error opening the app: %@", appError]);
        expect(waitForFile(marker), @"the app ran for the configuration variant");

        NSURL *web = [NSURL URLWithString:@"https://example.com/"];
        expect(![workspace openURL:web], @"-openURL: reports an unsupported scheme");
        __block NSError *webError = nil;
        [workspace openURL:web configuration:[NSWorkspaceOpenConfiguration configuration]
            completionHandler:^(NSRunningApplication *running, NSError *error) {
                webError = [error retain];
                dispatch_semaphore_signal(done);
            }];
        expect(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
               @"completion handler called for the web URL");
        expect([[webError domain] isEqual:NSOSStatusErrorDomain] && [webError code] == kLSApplicationNotFoundErr &&
                   [[[webError userInfo] objectForKey:NSURLErrorKey] isEqual:web],
               [NSString stringWithFormat:@"unsupported scheme error: %@", webError]);

        [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
        NSLog(@"PASS appkit-workspace-open-url");
    }
    return 0;
}
