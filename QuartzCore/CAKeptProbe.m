/* Diagnostic, not for commit. In-process: copy stderr through a pipe; when objc prints "no class for metaclass <ptr>",
   name that pointer with the public class_getName() and print only the name. */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <pthread.h>
#import <unistd.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>

static int gOrigErr = -1, gPipeRead = -1;

static void *teeThread(void *unused)
{
    char buf[4096], acc[8192];
    size_t accLen = 0;
    ssize_t n;
    while ((n = read(gPipeRead, buf, sizeof(buf))) > 0) {
        ssize_t off = 0;
        while (off < n) { ssize_t w = write(gOrigErr, buf + off, n - off); if (w <= 0) break; off += w; }
        if (accLen + n < sizeof(acc) - 1) { memcpy(acc + accLen, buf, n); accLen += n; acc[accLen] = 0; }
        else accLen = 0;
        const char *k = strstr(acc, "no class for metaclass 0x");
        if (k) {
            unsigned long long p = strtoull(k + strlen("no class for metaclass "), NULL, 16);
            const char *name = p ? class_getName((Class)(uintptr_t)p) : "(null)";
            char out[300];
            int len = snprintf(out, sizeof(out), "KEPTPROBE metaclass-name: %s\n", name ? name : "(nil)");
            write(gOrigErr, out, len);
            accLen = 0; acc[0] = 0;
        }
    }
    return NULL;
}

__attribute__((constructor)) static void keptProbeInit(void)
{
    int fds[2];
    if (pipe(fds) != 0) return;
    gOrigErr = dup(2);
    gPipeRead = fds[0];
    dup2(fds[1], 2);
    close(fds[1]);
    pthread_t t;
    pthread_create(&t, NULL, teeThread, NULL);
}
