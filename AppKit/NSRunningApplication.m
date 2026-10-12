#import <AppKit/NSRunningApplication.h>
#import <AppKit/NSDisplay.h>
#import <AppKit/NSErrors.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#include <errno.h>
#include <signal.h>

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

- (instancetype) initWithProcessIdentifier: (pid_t) processIdentifier {
    self = [super init];
    if (self) _processIdentifier = processIdentifier;
    return self;
}

+ (NSRunningApplication *) runningApplicationWithProcessIdentifier: (pid_t) processIdentifier {
    if (processIdentifier <= 0 || (kill(processIdentifier, 0) != 0 && errno == ESRCH))
        return nil;
    return [[[self alloc] initWithProcessIdentifier: processIdentifier] autorelease];
}

- (pid_t) processIdentifier {
    return _processIdentifier;
}

- (BOOL) isTerminated {
    return kill(_processIdentifier, 0) != 0 && errno == ESRCH;
}

- (BOOL) activateWithOptions: (NSUInteger) options {
    (void)options;
    if ([self isTerminated]) return NO;
    @try {
        return [[NSDisplay currentDisplay] activateProcessIdentifier: _processIdentifier];
    } @catch (NSException *exception) {
        if ([[exception name] isEqualToString:NSWindowServerCommunicationException])
            return NO;
        @throw;
    }
}

+ (NSArray<NSRunningApplication *> *) runningApplicationsWithBundleIdentifier: (NSString *) bundleIdentifier {
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return [NSArray array];
}

@end
