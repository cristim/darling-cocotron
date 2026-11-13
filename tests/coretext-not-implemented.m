// Links CoreText without AppKit. A CoreText name that cache frameworks import and Cocotron does not implement yet
// must exist here and fail loudly, naming itself, instead of falling through to another CoreText's code.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static void checkAborts(const char *name)
{
    void (*function)(void) = (void (*)(void))dlsym(RTLD_DEFAULT, name);
    expect(function != NULL, [NSString stringWithFormat:@"%s is defined", name]);

    int pipefd[2];
    expect(pipe(pipefd) == 0, @"pipe");
    pid_t child = fork();
    if (child == 0)
    {
        dup2(pipefd[1], 2);
        close(pipefd[0]);
        function();
        _exit(0);
    }
    close(pipefd[1]);
    char message[256] = {0};
    ssize_t count = read(pipefd[0], message, sizeof(message) - 1);
    int status = 0;
    waitpid(child, &status, 0);
    expect(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT, [NSString stringWithFormat:@"%s aborts", name]);
    expect(count > 0 && strstr(message, name) != NULL, [NSString stringWithFormat:@"%s names itself", name]);
}

int main(void)
{
    @autoreleasepool
    {
        checkAborts("CTFontDescriptorCreateWithTextStyle");
        checkAborts("CTLineGetRunCount");
        checkAborts("CTFontManagerCreateFontDescriptorFromData");
        // implemented names are not replaced
        expect(dlsym(RTLD_DEFAULT, "CTFontDescriptorCreateWithAttributes") != (void *)dlsym(RTLD_DEFAULT, "CTLineGetRunCount"),
               @"real functions are distinct from the net");
        NSLog(@"coretext-not-implemented: ok");
    }
    return 0;
}
