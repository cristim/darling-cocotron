// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Runs the real CTFontCopyName of CoreText/CTFont.m against mock CFEqual and name accessors.
 *
 * tests/coretext-copy-name.sh extracts the function text from CTFont.m. CoreFoundation's CFEqual halts when
 * either argument is NULL (CFRuntime.c: "CFEqual() called with NULL first argument"); the mock aborts the same
 * way. Apple documents the result as the requested name, or NULL if the font has no entry for the key, so a
 * NULL key must give NULL rather than take the process down. Each case runs in a child process so a crash is
 * reported as a failed check. */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

typedef const struct OpaqueFont *CTFontRef;
typedef const char *CFStringRef;
#define _Nullable

static const char kCTFontPostScriptNameKey[] = "postscript", kCTFontFamilyNameKey[] = "family",
                  kCTFontFullNameKey[] = "full";
static const char kPostScript[] = "Helvetica-Bold", kFamily[] = "Helvetica", kFull[] = "Helvetica Bold";
static int accessorCalls;

static int CFEqual(const void *a, const void *b)
{
    if (a == NULL || b == NULL)
        abort();
    return strcmp(a, b) == 0;
}
static CFStringRef CTFontCopyPostScriptName(CTFontRef font) { (void)font; accessorCalls++; return kPostScript; }
static CFStringRef CTFontCopyFamilyName(CTFontRef font) { (void)font; accessorCalls++; return kFamily; }
static CFStringRef CTFontCopyFullName(CTFontRef font) { (void)font; accessorCalls++; return kFull; }

#include FUNCTION_INC

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

/* Runs CTFontCopyName(font, key) in a child. Returns 0 when the child exits normally with the expected result
 * and no accessor call beyond expectCalls, 1 on a wrong result, and the signal number when it crashed. */
static int runCase(CTFontRef font, CFStringRef key, CFStringRef expect, int expectCalls)
{
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        accessorCalls = 0;
        CFStringRef name = CTFontCopyName(font, key);
        _exit(name == expect && accessorCalls == expectCalls ? 0 : 1);
    }
    int status = 0;
    waitpid(pid, &status, 0);
    if (WIFSIGNALED(status))
        return WTERMSIG(status);
    return WEXITSTATUS(status);
}

int main(void)
{
    CTFontRef font = (CTFontRef)&checks;
    int r;

    r = runCase(font, NULL, NULL, 0);
    CK(r == 0, "NULL key returns NULL without asking for any name (%s %d)", r > 1 ? "signal" : "result", r);
    r = runCase(NULL, NULL, NULL, 0);
    CK(r == 0, "NULL font and NULL key return NULL (%s %d)", r > 1 ? "signal" : "result", r);
    CK(runCase(font, kCTFontPostScriptNameKey, kPostScript, 1) == 0, "PostScript key gives the PostScript name");
    CK(runCase(font, kCTFontFamilyNameKey, kFamily, 1) == 0, "family key gives the family name");
    CK(runCase(font, kCTFontFullNameKey, kFull, 1) == 0, "full-name key gives the full name");

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
