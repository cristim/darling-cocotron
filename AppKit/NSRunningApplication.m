#import <AppKit/NSRunningApplication.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSProcessInfo.h>
#include <unistd.h>

// DUMMY

// Implementation notes:
// _LSCopyApplicationInformationItem(-2, ...) is used to fetch properties, such
// as _kLSExecutablePathKey Applications (processes) are referred to by an
// opaque void* asn (application serial number). ASNs can be compared with
// _LSCompareASNs().
//
// lsd provides notifications when processes change. This is registered via:
// _LSScheduleNotificationFunction(-2, callback, eventMask, context,
// CFRunLoopRef, kCFRunLoopCommonModes) and _LSModifyNotification(). The
// properties are updated via KVO.
//
// Current application is also observed via LS - _LSGetCurrentApplicationASN().
// All apps: _LSCopyRunningApplicationArray() - returns an array of ASNs.
// Running apps: _LSCopyRunningApplicationArray() - ditto.

@implementation NSRunningApplication

+ (NSArray<NSRunningApplication *> *) runningApplicationsWithBundleIdentifier: (NSString *) bundleIdentifier {
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return [NSArray array];
}

+ (instancetype) currentApplication {
    static NSRunningApplication *current = nil;
    @synchronized(self) {
        if (current == nil) {
            current = [[NSRunningApplication alloc] init];
            current->_processIdentifier = getpid();
        }
    }
    return current;
}

+ (instancetype) runningApplicationWithProcessIdentifier: (pid_t) pid {
    return pid == getpid() ? [self currentApplication] : nil;
}

- (pid_t) processIdentifier {
    return _processIdentifier;
}

- (NSString *) bundleIdentifier {
    return _processIdentifier == getpid() ? [[NSBundle mainBundle] bundleIdentifier] : nil;
}

- (NSString *) localizedName {
    if (_processIdentifier != getpid())
        return nil;
    NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"];
    return name ? name : [[NSProcessInfo processInfo] processName];
}

@end
