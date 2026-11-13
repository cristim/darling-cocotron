#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

// CTFontCreateCopyOfSystemUIFontWithGrade is exported so that clients bind; no public source documents its
// arguments, so a call aborts instead of returning an invented font.
int main(void) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, "CTFontCreateCopyOfSystemUIFontWithGrade");
    if (function == NULL) { printf("FAIL: the symbol is not exported\n"); return 1; }
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        function();
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    if (!(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT)) { printf("FAIL: a call did not abort\n"); return 2; }
    printf("PASS: CTFontCreateCopyOfSystemUIFontWithGrade fails loudly\n");
    return 0;
}
