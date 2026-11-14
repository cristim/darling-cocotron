#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// App Store imports the private AppKit function NSAccessibilityEntryPointActionNames. AppKit has to export it so
// the application binds; no public source says what it returns without an accessibility server, so a call aborts
// instead of inventing a result.
int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSArray *(*function)(id) = (NSArray *(*)(id)) dlsym(RTLD_DEFAULT, "NSAccessibilityEntryPointActionNames");
    EXPECT(function != NULL, "NSAccessibilityEntryPointActionNames is exported");

    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        function([NSObject new]);
        _exit(0);
    }
    int status = 0;
    EXPECT(waitpid(child, &status, 0) == child, "the child is reaped");
    EXPECT(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT, "calling it aborts");
    [pool drain];
    printf("PASS: NSAccessibilityEntryPointActionNames is exported and fails loudly\n");
    return 0;
}
